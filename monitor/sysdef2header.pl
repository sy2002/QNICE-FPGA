use strict;
use warnings;

die "Usage: $0 <sysdef-filename> <header-filename>\n" unless @ARGV == 2;

my ($sdf, $hf) = @ARGV;
open my $input, '<', $sdf or die "Could not open $sdf: $!\n";
open my $output, '>', $hf or die "Could not open $hf: $!\n";

while (my $line = <$input>)
{
    $line =~ s/;/\/\//;
    if ($line =~ /\.EQU/i)
    {
        my ($label, $rest) = $line =~ /^(.*)\s+\.EQU\s+(.*)$/i;
        $line = "#define $label\t$rest\n";
    }
    print $output $line;
}

close $output;
close $input;
