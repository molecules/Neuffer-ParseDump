#!/bin/env perl
package Neuffer::ParseDump;
# ABSTRACT: Parse fields from "mutantdb_dump.txt" in Dr. Neuffer's Mutant Database

#=============================================================================
# STANDARD MODULES AND PRAGMAS
use 5.010;    # Require at least Perl version 5.10
use strict;   # Must declare all variables before using them
use warnings; # Emit helpful warnings
use autodie;  # Fatal exceptions for common unrecoverable errors (e.g. open)
use Carp qw( croak );   # Throw errors from calling function

#=============================================================================
# ADDITIONAL MODULES


use Getopt::Long::Descriptive; # Parse @ARGV as command line flags and arguments
use File::Spec::Win32;


#=============================================================================
# CONSTANTS

my $IMAGE_FOLDER    = 'http://images.maizegdb.org/db_images/Variation/mgn';

# Regexes
my $FUNNY_CHAR = qr{ [- *,_@]}xms;

# Boolean
my $TRUE =1;
my $FALSE=0;

# String
my $SPACE        = q{ };
my $UNDERSCORE   = q{_};
my $EMPTY_STRING = q{};

my @REQUIRED_FLAGS = qw( infile outfile );

# CONSTANTS
#=============================================================================

#=============================================================================
# COMMAND LINE

# Run as a command-line program if not used as a module
main(@ARGV) if !caller();

sub main {

    #-------------------------------------------------------------------------
    # COMMAND LINE INTERFACE                                                 #
    #                                                                        #
    my ( $opt, $usage ) = describe_options(
        '%c %o <some-arg>',
        [ 'infile|i=s',  'input file name', ],
        [ 'outfile|o=s', 'output file name', ],
        [],
        [ 'help', 'print usage message and exit' ],
    );

    my $exit_with_usage = sub {
        print "\nUSAGE:\n";
        print $usage->text();
        exit();
    };

    # If requested, give usage information regardless of other options
    $exit_with_usage->() if $opt->help;

    # Make some flags required
    my $missing_required = $FALSE;
    for my $flag (@REQUIRED_FLAGS) {
        if ( !defined $opt->$flag ) {
            print "Missing required option '$flag'\n";
            $missing_required = $TRUE;
        }
    }

    # Exit with usage statement if any required flags are missing
    $exit_with_usage->() if $missing_required;

    #                                                                        #
    # COMMAND LINE INTERFACE                                                 #
    #-------------------------------------------------------------------------

    #-------------------------------------------------------------------------
    #                                                                        #
    #                                                                        #

    open( my $fh_in,  '<', $opt->infile );
    open( my $fh_out, '>', $opt->outfile );

    open(my $fh_invalid, '>>', 'invalid_image_names.txt');
    say {$fh_invalid} join("\t", 'Local filename', 'Error', 'Best match');

    my $valid_web_name_for = __valid_web_name_for( {fh_invalid => $fh_invalid} );

    while ( my $line = readline $fh_in ) {
        chomp $line;
        my @fields = split /\t/, $line;
        my $filename = $fields[-1];
        my $web_name = $valid_web_name_for->($filename) // $EMPTY_STRING;
        say {$fh_out} join( "\t", $line, $web_name );
    }

    close $fh_in;
    close $fh_out;
    return;

    #                                                                        #
    #                                                                        #
    #-------------------------------------------------------------------------
}

# COMMAND LINE
#=============================================================================


sub href_from_line {
    my $line = shift;

    my @fields = split /\t/, $line;

    # Capture each field from the line
    my $href =
    {
        labno                 => $fields[0],
        labsym                => $fields[1],
        phenotype             =>
            {
                name_lc     => lc $fields[2],
                name        => $fields[2],
                description => $fields[3],
            },
        image => {
            description     => $fields[4],
            local_filename  => $fields[5],
            web_filename    => stripped_munged_name_for($fields[5]),
        },
    };
    return $href;
}

sub href_from_file {
    my $fh = shift // die "Argument 'fh' required";
    my $group_number = 0;
    my %pheno_group;

    INPUT_LOOP:
    while(my $line = readline $fh){
        chomp $line;

        if($line eq $EMPTY_STRING){
            $group_number++;
            next INPUT_LOOP;
        }

        my $href_from_line = href_from_line($line);
        push @{ $pheno_group{$group_number}}, $href_from_line;
    }

    return \%pheno_group;
}

sub __valid_web_name_for {

    my $opt_href   = shift;
    my $fh_invalid = $opt_href->{fh_invalid}
      // croak 'fh_invalid is a required parameter';

    return sub {
        my $local_filename = shift;

        my $SINGLE_DIGIT_ENDING = qr{ [-](\d).jpg \z}xmsi;

        if ( !valid_local_filename($local_filename) ) {
            say {$fh_invalid} join( "\t",
                $local_filename, 'Filename lacks the string "Research Images"',
                $EMPTY_STRING );
            return;
        }
        else {
            return stripped_munged_name_for($local_filename);
        }

        croak 'This line should be unreachable';
      }
}

sub stripped_munged_name_for {
    my $local_filename = shift;

    my %webname_for_special_case = __webname_for_special_case();

    return $webname_for_special_case{$local_filename} if exists $webname_for_special_case{$local_filename};

    # Regex for matching file names having a single digit just before the string '.jpg'
    my $SINGLE_DIGIT_ENDING = qr{ [-](\d).jpg \z}xmsi;

    # Split filename into parts (These are presumably Windows filenames)
    my ( $volume, $directories, $basename ) =
      File::Spec::Win32->splitpath($local_filename);

    # Fix single digit endings
    if ( $basename =~ $SINGLE_DIGIT_ENDING ) {
        my $value  = $1;
        my $length = length $basename;
        $basename = substr( $basename, 0, $length - 6 ) . "_0$value.jpg";
    }

    # Replace spaces and funny characters with underscores, to more closely match web names
    $basename =~ s/$FUNNY_CHAR+/$UNDERSCORE/gxms;

    # Replace all non_extension_related periods
    $basename = replace_all_periods_except_with_jpg($basename);

    $basename = lc $basename;
    return $basename;
}

sub __webname_for_special_case {
    return ('Research Images\maize\85 series\85 23-46 Pg Chi-2633. 023.jpg' => '85_23_46_pg_chi_2633._023.jpg');
}

sub replace_all_periods_except_with_jpg {
    my $string = shift;

    # Any period that does not directly preceed the text "jpg" (in any case)
    my $NON_JPG_PERIOD = qr{ [.](?!jpg) }xmsi;

    $string =~ s/$NON_JPG_PERIOD/$UNDERSCORE/gxms; 

    return $string;
}

sub valid_local_filename {
    my $filename = shift;
    return $filename =~ /Research\sImages/;
}

sub remove_cd {
    my $string = shift;
    $string =~ s/\A cd//xmsi;
    return $string;
}

sub clean_web_filename {
    my $web_filename    = shift;

    # make all lowercase
    my $lc_web_filename = lc $web_filename;

    $lc_web_filename =~ s/$FUNNY_CHAR/_/g;

    # Copy lowercase filename, just in case no other changes are applied
    my $clean_web_filename = $lc_web_filename;

    # Extract the last part of the file name (the part that will be most pertinent to comparisons)
    my @clean_web_pieces   = split m{[\\\/]}, $lc_web_filename;
    my $last_piece         = $clean_web_pieces[-1];

    if ( length( $last_piece ) > 6 ) {
        $clean_web_filename = $last_piece;
    }
    else {
        $last_piece = $clean_web_pieces[-2] . $UNDERSCORE. $clean_web_pieces[-1];

        # Remove 'cd' from beginning of filename, 
        $clean_web_filename = remove_cd($last_piece);
    }

    return $clean_web_filename;
}

#-----------------------------------------------------------------------------

1;  #Modules must return a true value
=pod

=head1 SYNOPSIS

    perl Neuffer/ParseDump.pm --infile input_filename --outfile output_filename

=head1 DESCRIPTION

    Parses database dump from Dr. Neuffer's Access database. This dump is
    later used for creating pages for mutants.maizegdb.org. 

=head1 DEPENDENCIES

    Perl 5.10 or later

    Getopt::Long::Descriptive
    File::Spec::Win32

=head1 INCOMPATIBILITIES

    None known. However, this has only been tried on Linux systems.

=head1 BUGS AND LIMITATIONS

     There are no known bugs in this module.
     Please report problems to the author.
     Patches are welcome.
