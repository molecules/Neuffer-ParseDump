use 5.008;    # Require at least Perl version 5.8
use strict;   # Must declare all variables before using them
use warnings; # Emit helpful warnings
use autodie;  # Fatal exceptions for common unrecoverable errors (e.g. w/open)

# Testing-related modules
use Test::More;                  # provide testing functions (e.g. is, like)
use Test::LongString;            # Compare strings byte by byte
use Data::Section -setup;        # Set up labeled DATA sections
use File::Temp  qw( tempfile );  #
use File::Slurp qw( slurp    );  # Read a file into a string
use Data::Show;

# Distribution-specific modules
use lib 'lib';              # add 'lib' to @INC
use Neuffer::ParseDump;

my $FALSE = !! undef;

{
    my $result =
      Neuffer::ParseDump::replace_all_periods_except_with_jpg('A.B.C.jpg');
    my $expected = 'A_B_C.jpg';
    is( $result, $expected, 'All periods except last one replaced' );
}

{
    my $input    = "C:/Documents and Settings/Marley & Scrooge";
    my $result   = !! Neuffer::ParseDump::valid_local_filename($input);
    my $expected = $FALSE;

    is( $result, $FALSE, "Correctly identified '$input' as invalid for Neuffer photo file names" );

}

{
    my $input_filename  = filename_for('input');
    my $output_filename = temp_filename();
    system("perl lib/Neuffer/ParseDump.pm --infile $input_filename --outfile $output_filename");
    my $result   = slurp $output_filename;
    my $expected = string_from('expected');
    is_string( $result, $expected, 'successfully created output file' );

    delete_temp_file('invalid_image_names.txt');
}

{
    my $input_fh  = fh_from('input_1');
    my $line_num = 0;
    my $expected_line_href_aref = expected_line_hrefs();
    while ( my $line = readline $input_fh ) {
        chomp $line;
        my $line_href = Neuffer::ParseDump::href_from_line($line);
        is_deeply(
            $line_href,
            $expected_line_href_aref->[$line_num],
            'href correctly parsed from line'
        );
        $line_num++;
    }
}

done_testing();

sub expected_line_hrefs {
    return
    [
        {
            labno                 => 'G001.001',
            labsym                => 'A1-r',
            phenotype             =>
                {
                    name_lc     => 'anthocyanin',
                    name        => 'anthocyanin',
                    description => 'purple or red anthocyanin  pigments in aleurone of kernel, seedling and plant parts depending on modifying genes and red pigment in pericarp with P-r',
                },
            image => {
                description     => 'anthocyanin: kernel and pericarp.   Three ears segregating for purple or red color (A1) vs. colorless aleurone (a1/a1) on ears, respectively (top to bottom), with colorless pericarp (p1/p1); brown pericarp (with P1-rr/- and the A1-b allele); and red pericarp (P1-rr) with the common A1 allele.',
                local_filename  => 'Research Images\maize\WalMart CDs\7101-3161-0702\7101-3161-0702-55.jpg',
                web_filename    => '7101_3161_0702_55.jpg',
            },
        },
        {
            labno                 => 'G013',
            labsym                => 'B1',
            phenotype             =>
                {
                    name_lc     => 'booster of anthocyanin',
                    name        => 'Booster of anthocyanin',
                    description => 'booster (sunlight requiring red pigment in exposed pl1 tissue and deep purple anthocyanin when Pl1 is present.',
                },
            image => {
                description     => 'Booster of anthocyanin: Leaf sheath of a maturing B1/+, pl1/pl1 plant showing band of sunred (pl) pigment on older sheath tissue, above the previous night\'s still green emerging tissue, which will darken after sun exposure.  Had the Pl1 allele been present the sheath would be solid dark purple.',
                local_filename  => 'Research Images\maize\WalMart CDs\7101-3161-0706\7101-3161-0706-42.jpg',
                web_filename    => '7101_3161_0706_42.jpg',

            },
        },
    ];
}

sub sref_from {
    my $section = shift;

    #Scalar reference to the section text
    return __PACKAGE__->section_data($section);
}

sub string_from {
    my $section = shift;

    #Get the scalar reference
    my $sref = sref_from($section);

    #Return a string containing the entire section
    return ${$sref};
}

sub fh_from {
    my $section = shift;
    my $sref    = sref_from($section);

    #Create filehandle to the referenced scalar
    open( my $fh, '<', $sref );
    return $fh;
}

sub assign_filename_for {
    my $filename = shift;
    my $section  = shift;

    # Don't overwrite existing file
    die "'$filename' already exists." if -e $filename;

    my $string   = string_from($section);
    open(my $fh, '>', $filename);
    print {$fh} $string;
    close $fh;
    return;
}

sub filename_for {
    my $section           = shift;
    my ( $fh, $filename ) = tempfile();
    my $string            = string_from($section);
    print {$fh} $string;
    close $fh;
    return $filename;
}

sub temp_filename {
    my ($fh, $filename) = tempfile();
    close $fh;
    return $filename;
}

sub delete_temp_file {
    my $filename  = shift;
    my $delete_ok = unlink $filename;
    ok($delete_ok, "deleted temp file '$filename'");
}

#------------------------------------------------------------------------
# IMPORTANT!
#
# Each line from each section automatically ends with a newline character
#------------------------------------------------------------------------

__DATA__
__[ misc ]__
0	1	2	3	4	5	6
labno	labsym	name	phenotype	short_description	Filename	MaizeGDB_Filename	
__[ input ]__
2542	PgD	Pale Green Dwarf	Pale green dwarf; lazy growth, defective roots		Research Images\maize\92 series\92 55.1-6dbl hom,-7mod hom,-8mod het PgD-2542 DSC00337.JPG
A	B	C	D	C:/Documents and Settings/Marley & Scrooge
X	Y	Z	Research Images\maize\90 series\90 12-17 Hs-2559, Hs-2514 dbl 101MSDCF1 003.jpg
4	5	6	Research Images\maize\82 series\82 50 Les-2586Hom,Het 092.jpg
0001	wls	white luteus streak	yellowish, white seedling with faint yellow green longitudinal streaks		Research Images\maize\WalMart CDs\5194-1611-1258\5194-1611-1258-1.jpg
2528	GrNl	Grainy Narrow leaf	Narrow leaf bleached grainy pale green areas on either side of midrib, associated with narrowing of the leaf blade, especially In the lower half of the leaf; also reduction of the ligule	Grainy Narrow leaf:  Closeup of previous image showing pale green grainy leaf margins and dark green midrib tissue, typical of GrNl*-N2528.	Research Images\maize\79 series\04-06-22\79 169-12 GrNl-2528 DCP_0939.JPG
2625	AbMorp	Abnormal morphology			Research Images\maize\86 Series\86 34-1-2-3-4 NlDef-2625, 1990.JPG
2525	PgyV	Pigmy Virescent	Virescent seedling, Pigmy plant with short yellow green emerging leaves;	Pigmy Virescent:  A nearly mature PgmyV*-N2525/+ heterozygous mutant semidwarf plant (left) with short leaves  showing  yellow green emerging leaves and normal green lower leaves.  Also (right) a dwarf-like homozygote which had been very light green seedling but has greened up to normal.  Rapidly emerging tissue is most extreme.	Research Images\maize\77 series 03-07-28, 03-10-05\03-07-28gertucmoscor77\77@94-2 VSdw-2525 _069.jpg
2633	PgCb	Palegreen crossband	Pale green diurnal crossbands on lower leaves.	Palegreen crossband; chimera:  Original PgCb*-N2633/+ heterozygous chimeric mutant plant showing 1/2 plant sector of pale green tissue gradually changing to necrotic on lower leaves.	Research Images\maize\85 series\85 23-46 Pg Chi-2633. 023.jpg
__[ expected ]__
2542	PgD	Pale Green Dwarf	Pale green dwarf; lazy growth, defective roots		Research Images\maize\92 series\92 55.1-6dbl hom,-7mod hom,-8mod het PgD-2542 DSC00337.JPG	92_55_1_6dbl_hom_7mod_hom_8mod_het_pgd_2542_dsc00337.jpg
A	B	C	D	C:/Documents and Settings/Marley & Scrooge	
X	Y	Z	Research Images\maize\90 series\90 12-17 Hs-2559, Hs-2514 dbl 101MSDCF1 003.jpg	90_12_17_hs_2559_hs_2514_dbl_101msdcf1_003.jpg
4	5	6	Research Images\maize\82 series\82 50 Les-2586Hom,Het 092.jpg	82_50_les_2586hom_het_092.jpg
0001	wls	white luteus streak	yellowish, white seedling with faint yellow green longitudinal streaks		Research Images\maize\WalMart CDs\5194-1611-1258\5194-1611-1258-1.jpg	5194_1611_1258_01.jpg
2528	GrNl	Grainy Narrow leaf	Narrow leaf bleached grainy pale green areas on either side of midrib, associated with narrowing of the leaf blade, especially In the lower half of the leaf; also reduction of the ligule	Grainy Narrow leaf:  Closeup of previous image showing pale green grainy leaf margins and dark green midrib tissue, typical of GrNl*-N2528.	Research Images\maize\79 series\04-06-22\79 169-12 GrNl-2528 DCP_0939.JPG	79_169_12_grnl_2528_dcp_0939.jpg
2625	AbMorp	Abnormal morphology			Research Images\maize\86 Series\86 34-1-2-3-4 NlDef-2625, 1990.JPG	86_34_1_2_3_4_nldef_2625_1990.jpg
2525	PgyV	Pigmy Virescent	Virescent seedling, Pigmy plant with short yellow green emerging leaves;	Pigmy Virescent:  A nearly mature PgmyV*-N2525/+ heterozygous mutant semidwarf plant (left) with short leaves  showing  yellow green emerging leaves and normal green lower leaves.  Also (right) a dwarf-like homozygote which had been very light green seedling but has greened up to normal.  Rapidly emerging tissue is most extreme.	Research Images\maize\77 series 03-07-28, 03-10-05\03-07-28gertucmoscor77\77@94-2 VSdw-2525 _069.jpg	77_94_2_vsdw_2525_069.jpg
2633	PgCb	Palegreen crossband	Pale green diurnal crossbands on lower leaves.	Palegreen crossband; chimera:  Original PgCb*-N2633/+ heterozygous chimeric mutant plant showing 1/2 plant sector of pale green tissue gradually changing to necrotic on lower leaves.	Research Images\maize\85 series\85 23-46 Pg Chi-2633. 023.jpg	85_23_46_pg_chi_2633._023.jpg
__[ unmatched ]__
Local filename	Error	Best match
C:/Documents and Settings/Marley & Scrooge	Filename lacks the string "Research Images"
__[ imperfect_matches ]__
2625	AbMorp	Abnormal morphology			Research Images\maize\86 Series\86 34-1-2-3-4 NlDef-2625, 1990.JPG	86_34_1_2_3_4_nldef_2625_1990.jpg
X	Y	Z	Research Images\maize\90 series\90 12-17 Hs-2559, Hs-2514 dbl 101MSDCF1 003.jpg	90_12_17_Hs_2559_Hs_2514_dbl_101MSDCF1_003.jpg
__[ input_1 ]__
G001.001	A1-r	anthocyanin	purple or red anthocyanin  pigments in aleurone of kernel, seedling and plant parts depending on modifying genes and red pigment in pericarp with P-r	anthocyanin: kernel and pericarp.   Three ears segregating for purple or red color (A1) vs. colorless aleurone (a1/a1) on ears, respectively (top to bottom), with colorless pericarp (p1/p1); brown pericarp (with P1-rr/- and the A1-b allele); and red pericarp (P1-rr) with the common A1 allele.	Research Images\maize\WalMart CDs\7101-3161-0702\7101-3161-0702-55.jpg	http://images.maizegdb.org/db_images/Variation/cd7101-3161-0702/55.jpg
G013	B1	Booster of anthocyanin	booster (sunlight requiring red pigment in exposed pl1 tissue and deep purple anthocyanin when Pl1 is present.	Booster of anthocyanin: Leaf sheath of a maturing B1/+, pl1/pl1 plant showing band of sunred (pl) pigment on older sheath tissue, above the previous night's still green emerging tissue, which will darken after sun exposure.  Had the Pl1 allele been present the sheath would be solid dark purple.	Research Images\maize\WalMart CDs\7101-3161-0706\7101-3161-0706-42.jpg	
