use inc::Module::Install 1.00;
use strict;
use warnings;

use 5.008001;

use FindBin;
use lib "$FindBin::Bin/lib";
use DBIx::Class::Optional::Dependencies;

# get cpanX --installdeps . to behave in a checkout (most users do not need
# the deps for a full test suite run, and if they do - there's MI::AutoInstall
# for that)
##
## DO NOT USE THIS HACK IN YOUR DISTS!!! (it makes #toolchain sad)
##
$Module::Install::AUTHOR = 0 if (grep { $ENV{"PERL5_${_}_IS_RUNNING"} } (qw/CPANM CPANPLUS CPAN/) );

###
### DO NOT ADD OPTIONAL DEPENDENCIES HERE, EVEN AS recommends()
### All of them should go to DBIx::Class::Optional::Dependencies
###

name     'DBIx-Class';
perl_version '5.008001';
all_from 'lib/DBIx/Class.pm';

my $build_requires = {
  # needed for testing only, not for operation
  'DBD::SQLite'              => '1.29',
};

my $test_requires = {
  'File::Temp'               => '0.22',
  'Test::Builder'            => '0.33',
  'Test::Exception'          => '0.31',
  'Test::More'               => '0.92',
  'Test::Warn'               => '0.21',

  # this is already a dep of n::c, but just in case - used by t/55namespaces_cleaned.t
  # remove and do a manual glob-collection if n::c is no longer a dep
  'Package::Stash'           => '0.28',
};

my $runtime_requires = {
  'Class::Accessor::Grouped' => '0.10002',
  'Class::C3::Componentised' => '1.0009',
  'Class::Inspector'         => '1.24',
  'Config::Any'              => '0.20',
  'Context::Preserve'        => '0.01',
  'Data::Dumper::Concise'    => '2.020',
  'Data::Page'               => '2.00',
  'Hash::Merge'              => '0.12',
  'MRO::Compat'              => '0.09',
  'Module::Find'             => '0.06',
  'Path::Class'              => '0.18',
  'Scope::Guard'             => '0.03',
  'SQL::Abstract'            => '1.72',
  'Try::Tiny'                => '0.04',
  'Data::Compare'            => '1.22',

  # XS (or XS-dependent) libs
  'DBI'                      => '1.57',
  'namespace::clean'         => '0.20',
  'Sub::Name'                => '0.04',
  'Variable::Magic'          => '0.44',

  # dual-life corelibs needing a specific bugfixed version
  'File::Path'               => '2.07',
};


# Bail out on parallel testing
if (
  ($ENV{HARNESS_OPTIONS}||'') =~ / (?: ^ | \: ) j(\d+) /x
    and
  $1 > 1
) { die <<EOP }

******************************************************************************
******************************************************************************
***                                                                        ***
***      PARALLEL TESTING DETECTED ( \$ENV{HARNESS_OPTIONS} = 'j$1' )        ***
***                                                                        ***
*** DBIC tests will fail. It is harder to make them parallel-friendly than ***
*** it should be (though work is underway). In the meantime you will have  ***
*** to adjust your environment and re-run the installation. Sorry!         ***
***                                                                        ***
******************************************************************************
******************************************************************************

EOP

require Getopt::Long;
my $getopt = Getopt::Long::Parser->new(
  config => [qw/gnu_getopt bundling_override no_ignore_case pass_through/]
);
my $args = {
  skip_author_deps => undef,
};
$getopt->getoptions($args, 'skip_author_deps');
if (@ARGV) {
  warn "\nIgnoring unrecognized option(s): @ARGV\n\n";
}

# this is so we can order requires alphabetically
# copies are needed for author requires injection
my $reqs = {
  build_requires => { %$build_requires },
  requires => { %$runtime_requires },
  test_requires => { %$test_requires },
};

my %reqs_for_group = %{DBIx::Class::Optional::Dependencies->req_group_list};

# exclude the rdbms_* groups which are for DBIC users
my $opt_testdeps = {
  map { %{$reqs_for_group{$_}} } grep { !/^rdbms_/ } keys %reqs_for_group
};

# require extra modules for testing if we're in a checkout
my $optdep_msg;
if ($Module::Install::AUTHOR) {
  if ($args->{skip_author_deps}) {
    $optdep_msg = <<'EOW';

******************************************************************************
******************************************************************************
***                                                                        ***
*** IGNORING AUTHOR MODE: no optional test dependencies will be forced.    ***
***                                                                        ***
*** If you are using this checkout with the intention of submitting a DBIC ***
*** patch, you are *STRONGLY ENCOURAGED* to install all dependencies, so   ***
*** that every possible unit-test will run.                                ***
***                                                                        ***
******************************************************************************
******************************************************************************

EOW
  }
  else {
    $optdep_msg = <<'EOW';

******************************************************************************
******************************************************************************
***                                                                        ***
*** AUTHOR MODE: all optional test dependencies converted to hard requires ***
***       ( to disable re-run Makefile.PL with --skip_author_deps )        ***
***                                                                        ***
******************************************************************************
******************************************************************************

EOW

    $reqs->{test_requires} = {
      %{$reqs->{test_requires}},
      %$opt_testdeps
    };
  }
}

# compose final req list, for alphabetical ordering
my %final_req;
for my $rtype (keys %$reqs) {
  for my $mod (keys %{$reqs->{$rtype}} ) {

    # sanity check req duplications
    if ($final_req{$mod}) {
      die "$mod specified as both a '$rtype' and a '$final_req{$mod}[0]'\n";
    }

    $final_req{$mod} = [ $rtype, $reqs->{$rtype}{$mod}||0 ],
  }
}

# actual require
for my $mod (sort keys %final_req) {
  my ($rtype, $ver) = @{$final_req{$mod}};
  no strict 'refs';
  $rtype->($mod, $ver);
}

# output twice since the deplist is > 70 lines
warn $optdep_msg if $Module::Install::AUTHOR;
auto_install();
warn $optdep_msg if $Module::Install::AUTHOR;


# re-create various autogenerated documentation bits
if ($Module::Install::AUTHOR) {

  # adjust ENV for $AUTHOR system() calls
  require Config;
  $ENV{PERL5LIB} = join ($Config::Config{path_sep}, @INC);

  print "Regenerating README\n";
  system('pod2text lib/DBIx/Class.pm > README');

  if (-f 'MANIFEST') {
    print "Removing MANIFEST\n";
    unlink 'MANIFEST';
  }

  print "Regenerating Optional/Dependencies.pod\n";
  require DBIx::Class::Optional::Dependencies;
  DBIx::Class::Optional::Dependencies->_gen_pod (Meta->version);

  # FIXME Disabled due to unsolved issues, ask theorbtwo
  #  require Module::Install::Pod::Inherit;
  #  PodInherit();
}


tests_recursive (qw|
    t
|);

# temporary(?) until I get around to fix M::I wrt xt/
# needs Module::Install::AuthorTests
eval {
  # this should not be necessary since the autoloader is supposed
  # to work, but there were reports of it failing
  require Module::Install::AuthorTests;
  recursive_author_tests (qw/xt/);
  1;
} || do {
  if ($Module::Install::AUTHOR && ! $args->{skip_author_deps}) {
    my $err = $@;

    # better error message in case of missing dep
    eval { require Module::Install::AuthorTests }
      || die "\nYou need Module::Install::AuthorTests installed to run this Makefile.PL in author mode (or supply --skip_author_deps):\n\n$@\n";

    die $err;
  }
};


install_script (qw|
    script/dbicadmin
|);


### Mangle makefile - read the comments for more info
#
postamble <<"EOP";

# This will add an extra dep-spec for the distdir target,
# which `make` will fold together in a first-come first-serve
# fashion. What we do here is essentially adding extra
# commands to execute once the distdir is assembled (via
# create_distdir), but before control is returned to a higher
# calling rule.
distdir : dbicadmin_pod_inject

# The pod self-injection code is in fact a hidden option in
# dbicadmin itself
dbicadmin_pod_inject :
\tcd \$(DISTVNAME) && \$(ABSPERL) -Ilib script/dbicadmin --selfinject-pod

# Regenerate manifest before running create_distdir.
create_distdir : manifest

EOP

homepage 'http://www.dbix-class.org/';
resources 'IRC'         => 'irc://irc.perl.org/#dbix-class';
resources 'license'     => 'http://dev.perl.org/licenses/';
resources 'repository'  => 'git://git.shadowcat.co.uk/dbsrgits/DBIx-Class.git';
resources 'MailingList' => 'http://lists.scsys.co.uk/cgi-bin/mailman/listinfo/dbix-class';
resources 'bugtracker'  => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-Class';

# Deprecated/internal modules need no exposure
no_index directory => $_ for (qw|
  lib/DBIx/Class/Admin
  lib/DBIx/Class/PK/Auto
  lib/DBIx/Class/CDBICompat
|);
no_index package => $_ for (qw/
  DBIx::Class::Storage::DBIHacks
  DBIx::Class::Carp
/);

WriteAll();

# Re-write META.yml to _exclude_ all forced build-requires (we do not want to ship
# this) We are also not using M::I::AuthorRequires as this will be an extra dep,
# and deps in Makefile.PL still suck
# Also always test the result so we stop shipping borked dependency lists to CPAN

# FIXME test_requires is not yet part of META
my %original_build_requires = ( %$build_requires, %$test_requires );
my @all_build_requires = @{delete Meta->{values}{build_requires}};
my %removed_build_requires;

for (@all_build_requires) {
  if ($original_build_requires{$_->[0]}) {
    push @{Meta->{values}{build_requires}}, $_;
  }
  else {
    $removed_build_requires{$_->[0]} = $_->[1]
      unless $_->[0] eq 'ExtUtils::MakeMaker';
  }
}

# Rewrite only in author mode, the original META should not contain anything anyway
# if we executed as non-author
if ($Module::Install::AUTHOR && keys %removed_build_requires) {
  print "Regenerating META with author requires excluded\n";
  Meta->write;
}

# test that we really took things away (just in case, happened twice somehow)
if (! -f 'META.yml') {
  warn "No META.yml generated?! aborting...\n";
  exit 1;
}
my $meta = do { local @ARGV = 'META.yml'; local $/; <> };

# this is safe as there is a fatal check earlier to make sure $opt_testdeps does
# not contain any real dependencies
my @illegal_leftovers = grep
  { $meta =~ /^ \s+ \Q$_\E \: \s+ /mx }
  ( sort keys %$opt_testdeps )
;

if (@illegal_leftovers) {
  die join ("\n",
    "\n\nFATAL FAIL! It looks like some author dependencies made it to the META.yml:\n",
    map { "\t$_" } @illegal_leftovers
  ) . "\n\n";
}
