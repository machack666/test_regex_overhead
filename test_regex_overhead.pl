#!/usr/bin/perl

use strict;
use warnings;
use autodie;

require 5.010;                       # needed for *FAIL regex verb

use Data::Dumper;

# latest versions in each major branch
my @default_versions = qw/5.8.9 5.10.1 5.12.5 5.14.4 5.16.3 5.18.4 5.20.3 5.22.3 5.24.1 5.26.1/;
my @target_versions = @ARGV ? @ARGV : @default_versions;

my @axes = qw/Encode Safe UTF8/;
my %script_re = get_script_re();

install_missing_versions();
setup_scripts();
check_scripts();
print "Everything generated; sleeping 5 so you can cancel...\n";
sleep 5;
run_tests();


#################### Routines ####################

sub get_script_re {
    # return permutations/regexes for all combinations of the axes
    # using the fact that bitwise operations encode all perms for the powers of two

    my %regs;
    my %col_offset;
    @col_offset{@axes} = (0..@axes-1);
    for my $perm (0..2**@axes-1) {
        my @re;
        my @fn;
        for my $axis (@axes) {
            my $include = vec $perm, $col_offset{$axis}, 1;
            push @re, $axis if $include;
            push @fn, ($include ? 'no' : '') . lc $axis;
        }
        my $re = @re ? join '|', @re : '(*FAIL)';
        my $fn = (join '_' => ('with', @fn)) . '.pl';
        $regs{$fn} = qr/$re/;
    }
    return %regs;
}

sub run_tests {
    my @fns = sort keys %script_re;
    for my $vers (@target_versions) {
        for my $fn (@fns) {
            print "Version: $vers ($fn)\n";
            system("PLENV_VERSION=$vers time plenv exec perl $fn");
        }
    }
}

sub setup_scripts {
    my @prog = <DATA>;

    my @fns = sort keys %script_re;
    my %fh;
    
    open $fh{$_}, '>', $_ for @fns;

    for (@prog) {
        for my $fn (@fns) {
            $fh{$fn}->print($_) unless /$script_re{$fn}/;
        }
    }
    close $fh{$_} for @fns;
}

sub check_scripts {
    my @fns = sort keys %script_re;

    system("perl -cw $_") for @fns;
}

sub install_missing_versions {
    my %existing_versions = get_perl_versions();
    my @missing = grep { !exists $existing_versions{$_} } @target_versions;
    for my $vers (@missing) {
        system("plenv install $vers");
    }
}

sub get_perl_versions {
    my @vers = qx(plenv versions --bare);
    chomp @vers;
    return ( map { $_ => $_ } @vers );
}


__DATA__
#!/usr/bin/perl -l
use strict;
use warnings;

use utf8;                       # UTF8
use Encode;
use Safe;

my $highbit = "¿qué pasa?";     # Encode
$highbit =~ /¢/;                # Encode

Encode->find_encoding('utf8');

binmode(\*STDOUT, ':utf8');     # Encode

my $mySafe = new Safe();
$mySafe->untrap(qw/print/);

my $SafeStr = <<'EOSafe';
my $big_string = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" x 10_000_000;
$big_string = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" x 10_000_000;

$big_string .= "Easy as 123";
$big_string =~ /do-rey-mi/;

(substr $big_string, 100_000, 200) = "\xFF\xFF\xFF";

$big_string =~ /do-rey-mi/;
(substr $big_string, 200_000, 200) = "\xFF\xFF\xFF";

$big_string =~ /(\xFF\xFF\xFF)/;

if ($1) {

}

$big_string =~ s/XYZ//g; # don't like the XYZs!

$big_string =~ s/EFG/ABC/g;
$big_string =~ s/ABC/XXX/g;

print "done!";
EOSafe

$mySafe->reval($SafeStr);
warn "Safe had issues: $@" if $@;

