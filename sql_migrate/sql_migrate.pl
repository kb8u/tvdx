#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';
use Capture::Tiny ':all';
use File::Temp 'tempfile';
use Text::CSV::Easy 'csv_parse';
use List::Util 'any';

my $sqlite3 = '/usr/bin/sqlite3';
my $db = '/dev/shm/tvdx.db';
my @csv_db = ('-csv',$db);

my $mysql = '/usr/bin/mysql';
my @mysql_args = qw(--user=rjd
                    --password=...
                    --database=tvdx
                    --show-warnings
                    --verbose
                    -e); # -e is execute the following command


sub delete_tables {
    my ($fh, $tempfile) = tempfile();
    print $fh <<EODELETE;
delete from psip_virtual;
delete from tsid;
delete from rabbitears_call;
delete from rabbitears_tsid;
delete from signal_report;
delete from fcc;
delete from tuner_number;
delete from tuner;
EODELETE
    my ($stdout, $stderr, $exit) = capture {
        system( $mysql,(@mysql_args,"source $tempfile;") );
    };
    if ($exit) {
        print $stdout;
        say "can't delete tables: $stderr";
    }
    close $fh;
}

sub dump_table {
    my ($table) = @_;

    while (1) {
        my ($stdout, $stderr, $exit) = capture {
            system( $sqlite3,(@csv_db,"select * from $table;") );
        };
        if ($exit) {
            say "$table: $stderr";
            sleep 2;
        } else { return $stdout }
    }
}

sub insert_table {
    my ($name,$csv,$number_column) = @_;

    my $sql;
    foreach my $line (@$csv) {
        my @column = csv_parse($line);
        for (my $i=0; $i <= $#column; $i++) {
            if (!defined $column[$i]) {
                $column[$i] = 'NULL';
                next;
            }
            next if any {$i == $_} @$number_column;
            $column[$i] =~ s/\s$// unless $name eq 'psip_virtual' && $i == 2;
            $column[$i] =~ s/\p{FORMAT}$//;
            $column[$i] =~ s/'/''/g;
            $column[$i] = "'$column[$i]'";
        }

        $#column = 9 if $name eq 'signal_report';

        # tuner and fcc key is not auto_increment, others are
        unless (any {$_ eq $name} (qw (tuner fcc))) {
           $column[0] = 'NULL';
        }

        $sql .= "INSERT INTO $name VALUES(";
        $sql .= join ',',(@column);
        $sql .= ");\n";
    }

    my ($fh, $tempfile) = tempfile();
    print $fh $sql;
    my ($stdout, $stderr, $exit) = capture {
        system( $mysql,(@mysql_args,"source $tempfile;") );
    };
    if ($exit) {
        print $stdout;
        say "$name: $stderr";
    }
    close $fh;
}


say "deleting tables";
delete_tables();

say "running tuner import";
my @tuner = split /\n/, dump_table('tuner');
insert_table('tuner',\@tuner,[1,2]);

say "running tuner_number import";
my @tuner_number = split /\n/, dump_table('tuner_number');
insert_table('tuner_number',\@tuner_number,[0]);

say "running fcc import";
my @fcc = split /\n/, dump_table('fcc');
insert_table('fcc',\@fcc,[1,2,3,6]);

say "running signal import";
my @signal = split /\n/, dump_table('signal');
insert_table('signal_report',\@signal,[0,3,4,5,9]);

say "running rabbitears_tsid import";
my @rabbitears_tsid;
foreach my $line (split /\n/, dump_table('rabbitears_tsid')) {
    if ($line =~ /^\d+,/) { push @rabbitears_tsid, $line }
    else { $rabbitears_tsid[$#rabbitears_tsid] .= "\n$line"; }
}
insert_table('rabbitears_tsid',\@rabbitears_tsid,[0,1]);

say "running rabbitears_call import";
my @rabbitears_call;
foreach my $line (split /\n/, dump_table('rabbitears_call')) {
    if ($line =~ /^\d+,/) { push @rabbitears_call, $line }
    else { $rabbitears_call[$#rabbitears_call] .= "\n$line"; }
}
insert_table('rabbitears_call',\@rabbitears_call,[0]);

say "running tsid import";
my @tsid = split /\n/, dump_table('tsid');
insert_table('tsid',\@tsid,[0,2]);

say "running virtual import";
my @virtual = split /\n/, dump_table('virtual');
insert_table('psip_virtual',\@virtual,[0]);
