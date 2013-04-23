use Cwd 'abs_path';

sub image_dir {
  my @path_parts = split '/',abs_path($0);
  $#path_parts -= 2;
  return(join '/',@path_parts , 'root/static/images');
}

1;
