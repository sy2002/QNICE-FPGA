use strict;
use warnings;

die "Usage: $0 [-p <prefix> | -vasm] <sysdef-filename> <header-filename>\n" if @ARGV < 2;

my $vasm_mode = 0;
my $prefix = '';
if ($ARGV[0] =~ /-p/)
{
    $prefix = uc $ARGV[1];
    shift @ARGV;
    shift @ARGV;
}
if ($ARGV[0] =~ /-vasm/)
{
    $vasm_mode = 1;
    shift @ARGV;
}

my ($sdf, $hf) = @ARGV;
open my $input, '<', $sdf or die "Could not open $sdf: $!\n";
open my $output, '>', $hf or die "Could not open $hf: $!\n";

while (my $line = <$input>)
{
    next if $line =~ /^#define/;

    if ($vasm_mode == 0)
    {
        $line =~ s/;/\/\//;     # Transform ';'-comments into '//'-comments
        $line =~ s/\$/_/g;      # Get rid of dollar signs (I miss them! :-) )
    }

    if ($line =~ /\.EQU/i)  # This line contains an '.EQU', so we have to transform it
    {
        my ($label, $rest) = $line =~ /^(.*)\s+\.EQU\s+(.*)$/i;

        if ($vasm_mode == 0)
        {
            $label = uc $label;
        }

        if ($vasm_mode == 0)
        {
            $line = "#define $prefix$label\t$rest\n";
        }
        else
        {
            $line = ".equ $label,\t$rest\n";        
        }
    }
    print $output $line;    # Write line (possibly modified) to the output file
}

close $output;
close $input;
