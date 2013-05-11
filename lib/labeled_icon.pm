use GD;
use lib '/home/kb8u/tvdx/lib';
use image_dir;

# create a rectangle filled with $background_color contaning $text
# $text has to be no more than 4 characters
# output is to /tmp/$text.png
sub icon_png {
  my ($text,$background_color) = @_;

  # create a new image
  my $width = 2 + length($text) * 5;
  my $im = new GD::Image($width,9);

  # allocate some colors
  my $white = $im->colorAllocate(255,255,255);
  my $black = $im->colorAllocate(0,0,0);       
  my $red = $im->colorAllocate(255,0,0);      
  my $yellow = $im->colorAllocate(255,255,0);
  my $green = $im->colorAllocate(0,0,255);

  my %color_for = ( 'white' => $white,
                    'black' => $black,
                    'red'   => $red,
                    'yellow'=> $yellow,
                    'green' => $green, );

  # draw a black rectangle
#  $im->rectangle(0,0,20,10,$black); 

  # fill with background color
  $im->fillToBorder(5,5,$color_for{$background_color},$white);

  # write text
  $im->string(gdTinyFont,1,1,$text,$black);

  my $icon_path = image_dir() . "/$text.png";
  open ICON, "> $icon_path" or return 0;
  print ICON $im->png;
  close ICON;

  return 1;
}

1;
