use strict;
use warnings;

die "Usage: $0 <sysdef-filename> <header-filename>\n" unless @ARGV == 2;

my ($sdf, $hf) = @ARGV;
open my $input, '<', $sdf or die "Could not open $sdf: $!\n";
open my $output, '>', $hf or die "Could not open $hf: $!\n";

while (my $line = <$input>)
{
    next if $line =~ /^#define/;
    $line =~ s/;/\/\//;     # Transform ';'-comments into '//'-comments
    $line =~ s/\$/_/g;      # Get rid of dollar signs (I miss them! :-) )
    if ($line =~ /\.EQU/i)  # This line contains an '.EQU', so we have to transform it
    {
        my ($label, $rest) = $line =~ /^(.*)\s+\.EQU\s+(.*)$/i;
        $line = "#define $label\t$rest\n";
    }
    print $output $line;    # Write line (possibly modified) to the output file
}

close $output;
close $input;
