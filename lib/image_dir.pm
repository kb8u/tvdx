use Cwd 'abs_path';

# was supposed to cleverly derive the path to the image directory from
# the executable, but it doesn't work under fastcgi. -rjd May 11, 2013
sub image_dir {
#  my @path_parts = split '/',abs_path($0);
#  $#path_parts -= 2;
#  return(join '/',@path_parts , 'root/static/images');
  return('/home/kb8u/tvdx/root/static/images');
}

1;
