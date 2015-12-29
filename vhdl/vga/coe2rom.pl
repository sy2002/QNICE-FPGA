use strict;
use warnings;

my ($filename) = @ARGV;
my $out_fn = "$filename.rom";
die "Usage: $0\n" unless @ARGV == 1;
open my $handle, '<', $filename or die "Could not open $filename: $!\n";
open my $output, '>', $out_fn   or die "Could not open $out_fn: $!\n";

while (my $line = <$handle>)
{
    $line =~ s/\r//;
    $line =~ s/\n//;
    next if $line !~ /^[0-9A-F]{2}/;
    printf $output "%08b\n", hex($line);
}

close $output;
close $handle;
