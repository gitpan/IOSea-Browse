use Test::More tests => 6;

BEGIN {
use_ok( 'IOSea::Browse' );
}

my $params = { sql    => "select count(*) from test",
	       no_dbh => "dude",
               urls   => { root => 'http://bioinformatics.ualr.edu/', browse => 'cgi-bin/eg/browse.cgi'},
	       sort   => "dude" };
my $Browse = IOSea::Browse->new( $params );

my $sql    = $Browse->build_sql();
ok( $sql, "Build SQL" );

$Browse->set_sort_vec( 'desc' );
   $sql    = $Browse->build_sql();
ok( $sql, "Set Sort Vector" );

$Browse->flip_sort_vec();
   $sql    = $Browse->build_sql();
ok( $sql, "Flip Sort Vector" );

my $js     = $Browse->_build_javascript();
ok( $js, "Build Javascript" );

my $styles = $Browse->_build_styles();
ok( $styles, "Build Styles" );

diag( "Testing IOSea::Browse $IOSea::Browse::VERSION" );
