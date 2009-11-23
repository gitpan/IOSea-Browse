package IOSea::Browse;
use Class::Std;
use Class::Std::Utils;
use DBIx::MySperqlOO;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('1.0.0');

{
        my %dbh_of       :ATTR( :get<dbh>      :set<dbh>                                          );
        my %connect_of   :ATTR( :get<connect>  :set<connect>  :default<{}>    :init_arg<connect>  );
        my %fields_of    :ATTR( :get<fields>   :set<fields>   :default<'20'>  :init_arg<fields>   );
        my %sql_of       :ATTR( :get<sql>      :set<sql>      :default<''>    :init_arg<sql>      );
        my %urls_of      :ATTR( :get<urls>     :set<urls>     :default<{}>    :init_arg<urls>     );
        my %sort_of      :ATTR( :get<sort>     :set<sort>     :default<''>    :init_arg<sort>     );
        my %sort_vec_of  :ATTR( :get<sort_vec> :set<sort_vec> :default<'asc'> :init_arg<sort_vec> );
        my %window_of    :ATTR( :get<window>   :set<window>   :default<'20'>  :init_arg<window>   );
        my %index_of     :ATTR( :get<index>    :set<index>    :default<'0'>   :init_arg<index>    );
        my %count_of     :ATTR( :get<count>    :set<count>    :default<'0'>                       );
        my %features_of  :ATTR( :get<features> :set<features> :default<{}>    :init_arg<features> );

        my %classes_of   :ATTR( :get<classes>  :set<classes>  :default<['browseRowA','browseRowB']>  :init_arg<classes> );
                
        sub BUILD {
                my ( $self, $ident, $arg_ref ) = @_;
                return;
        }

        sub START {
                my ( $self, $ident, $arg_ref ) = @_;
		if (! defined $arg_ref->{no_dbh} ) {
			$self->set_dbh( DBIx::MySperqlOO->new($self->get_connect()) );
		}
                return;
        }

	sub dbh { my ( $self ) = @_; return $self->get_dbh(); }

	sub delete_enabled  { 
		my ( $self ) = @_; 
		my $delete   = '';
		if ( defined $self->get_features()->{delete} ) { $delete = $self->get_features()->{delete}; }
		return $delete;
	}

	sub args_to_attributes {
		my ($self, $arg_ref) = @_;
		if ( defined $arg_ref->{index} )    { $self->set_index( $arg_ref->{index} );       }
		if ( defined $arg_ref->{window} )   { $self->set_window( $arg_ref->{window} );     }
		if ( defined $arg_ref->{sort} )     { $self->set_sort( $arg_ref->{sort} );         }
		if ( defined $arg_ref->{sort_vec} ) { $self->set_sort_vec( $arg_ref->{sort_vec} ); }
		if ( defined $arg_ref->{features} ) { $self->set_features( $arg_ref->{features} ); }
	}

	sub build {
		my ($self, $arg_ref) = @_;
		my $build            = {};

		$self->args_to_attributes( $arg_ref );
		$self->set_count( $self->_get_row_count() );

		$build->{browse_styles}   = $self->_build_styles();
		$build->{browse_script}   = $self->_build_javascript();
		$build->{browse_action}   = $self->get_urls()->{root} . $self->get_urls()->{browse};
		$build->{browse_table}    = $self->_build_table();
		$build->{browse_sorted}   = $self->_build_sorted();
		$build->{browse_start}    = $self->_build_start();
		$build->{browse_prevnext} = $self->_build_prev_next();
		$build->{browse_show}     = $self->_build_show();
		$build->{browse_goto}     = $self->_build_goto();
		$build->{browse_control}  = $self->_build_control();
		$build->{browse_delete}   = $self->_build_delete();

		if (defined $self->get_features->{default_html} ) {             # Defined And
			if ( $self->get_features->{default_html} ) {            # Also True
				return $self->_build_default_html( $build );
			} else { return $build; }                               # Default HTML False
		} else {
			return $build;                                          # Default HTML Undefined
		}
	}

	sub build_sql {
		my ( $self, $arg_ref ) = @_;
		my $sql                = $self->get_sql();
		my $sort               = $self->get_sort();
		my $sort_vec           = $self->get_sort_vec();
		my $index              = $self->get_index();
		my $window             = $self->get_window();

		# Add sort
		if ( $sort ) { $sql .= " order by $sort $sort_vec"; }

		# Add limit
		$sql .= " limit $index, $window";

		return $sql;
	}

	sub _build_javascript {
		my ( $self ) = @_;
		my $html     = '<script language="javascript">' . "\n";
                   $html    .= 'function browseSetIndex(index) {' . "\n";
                   $html    .= '	document.getElementById("index").value = index;' . "\n";
                   $html    .= '	document.browse.submit();' . "\n";
                   $html    .= '}' . "\n";
                   $html    .= 'function browseSort(sort) {' . "\n";
                   $html    .= '	var current = document.getElementById("sort").value;' . "\n";
                   $html    .= '	if ( current == sort ) {' . "\n";
                   $html    .= '	    var vector = document.getElementById("sort_vec").value;' . "\n";
                   $html    .= '	    if ( vector == "asc" ) {' . "\n";
                   $html    .= '	        document.getElementById("sort_vec").value = "desc";' . "\n";
                   $html    .= '	    } else {' . "\n";
                   $html    .= '	        document.getElementById("sort_vec").value = "asc";' . "\n";
                   $html    .= '	    }' . "\n";
                   $html    .= '	} else {' . "\n";
                   $html    .= '	    document.getElementById("sort_vec").value = "asc";' . "\n";
                   $html    .= '	}' . "\n";
                   $html    .= '	document.getElementById("sort").value = sort;' . "\n";
                   $html    .= '	document.browse.submit();' . "\n";
                   $html    .= '}' . "\n";
		if ( $self->delete_enabled() eq 'multi' ) {
			my $url   = $self->get_urls()->{root} .  $self->get_urls()->{delete};
                	   $html .= 'function browseDelete() {' . "\n";
			   $html .= '	var myIDs = new Array();' . "\n";
			   $html .= '	for ( var i = 0; i < document.browse.elements.length; i++ ) {' . "\n";
			   $html .= '		if (document.browse.elements[i].type == "checkbox" ) {' . "\n";
			   $html .= '			if (document.browse.elements[i].checked) {' . "\n";
			   $html .= '				var DelID = document.browse.elements[i].name.split(".");' . "\n";
			   $html .= '				if (DelID[0] == "delete") {' . "\n";
			   $html .= '					myIDs.push(DelID[1]);' . "\n";
			   $html .= '				}' . "\n";
			   $html .= '			}' . "\n";
			   $html .= '		}' . "\n";
			   $html .= '	}' . "\n";
                	   $html .= '	document.getElementById("delete_ids").value = myIDs.join();' . "\n";
                	   $html .= '	document.browse.action = "' . $url . '";' . "\n";
                	   $html .= '	document.browse.submit();' . "\n";
                	   $html .= '}' . "\n";
		}
		   $html    .= '</script>' . "\n";
		return $html;
	}

	sub _build_styles {  
	        my $styles  = <<STYLES_END;
	        <style type=\"text/css\">            
	                HTML                         { background-color:#FFFFFF; }
	                BODY                         { background-color:#FFFFFF; } 
	                TD                           { font-family:arial; font-size:9pt; } 
	                TD.browseHead                { background-color:#666666; color:white; padding-left:4; padding-right:4; text-a
	                TD.browseRowA                { background-color:#FFEEEE; font-size:9pt; padding-left:2; color:black; text-ali
	                TD.browseRowB                { background-color:#FFDDDD; font-size:9pt; padding-left:2; color:black; text-ali
	                A.browseHead:link            { color:#FFFFFF; text-decoration:underline; }
	                A.browseHead:visited         { color:#FFFFFF; text-decoration:underline; }
	                A.browseHead:hover           { color:#FFFFFF; text-decoration:underline; }
	                A.browseLink:link            { color:#660000; text-decoration:underline; }
	                A.browseLink:visited         { color:#660000; text-decoration:underline; }
	                A.browseLink:hover           { color:#660000; text-decoration:underline; } 
	                A.browseDelete:link          { color:#000000; text-decoration:underline; padding-left:4; padding-right:4; }
	                A.browseDelete:visited       { color:#000000; text-decoration:underline; padding-left:4; padding-right:4; }
	                A.browseDelete:hover         { color:#000000; text-decoration:underline; padding-left:4; padding-right:4; }
	                A.browsePrevNextOn:link      { color:#000000; text-decoration:underline; font-size:9pt; }
	                A.browsePrevNextOn:visited   { color:#000000; text-decoration:underline; font-size:9pt; }
	                A.browsePrevNextOn:hover     { color:#000000; text-decoration:underline; font-size:9pt; } 
	                font.browseInfo              { font-family:arial; text-align:left; line-height:110%; font-style:italic; font-
	                font.browsePrevNextOff       { color:#999999; text-decoration:underline; font-size:9pt; }
	                font.browsePrevNextOff       { color:#999999; text-decoration:underline; font-size:9pt; }
	                font.browsePrevNextOff       { color:#999999; text-decoration:underline; font-size:9pt; } 
	                .browseSmallBox              { font-family:arial; font-size:7pt; height:16; width:18; text-align:center; colo
	                .browseSmallSelect           { font-family:arial; font-size:7pt; height:16; text-align:center; color:#660000;
	                .browseSmallButton           { font-family:arial; font-size:7pt; height:16; text-align:center; color:#FFFFFF;
	        </style>
STYLES_END
	        return $styles;
	}

	sub _build_table {
		my ($self, $arg_ref) = @_;

		my $fields      = $self->get_fields();
		my @classes     = @{ $self->get_classes() };
		my $class_count = scalar(@classes);
		my $class_index = 0;
		my $rows        = $self->_get_rows( $arg_ref );

		my $html        = '<table border="0" cellspacing="0" cellpadding="0" width="100%">' . "\n";
		   $html       .= $self->_build_header();

		foreach my $row ( @$rows ) {
			my $class       = $classes[($class_index++) % $class_count];
			my $field_count = 0;
			my @permitted   = ();

			$html          .= '  <tr>' . "\n";
			my $delete = $self->delete_enabled();
			if    ( $delete eq 'multi' ) {
				my $id   = $row->[0];
				$html   .= '    <td valign="top" class="' . $class . '"> <input type="checkbox" name="delete.' . $id . '" id="delete.' . $id . '"> </td>' . "\n";
			} 
			elsif ( $delete ) {
				my $url  = $self->get_urls()->{root} .  $self->get_urls()->{delete};
				my $id   = $row->[0];
				$html   .= '    <td valign="top" class="' . $class . '"> <a class="browseDelete" href="' . $url . $id . '">[X]</a></td>' . "\n";
			}
			foreach my $data ( @$row ) {
				if (! $fields->[$field_count]->{hide} ) {
					if ( $fields->[$field_count]->{link} ) {
						my $url  = $self->get_urls()->{root} .  $self->get_urls()->{ $fields->[$field_count]->{link} };
						my $id   = $row->[$fields->[$field_count]->{id}];
						$html   .= '    <td valign="top" class="' . $class . '"> <a class="browseLink" href="' . $url . $id . '">' . $data . '</a></td>' . "\n";
					} else {
						$html   .= '    <td valign="top" class="' . $class . '"> ' . $data . '</td>' . "\n";
					}
				}
				$field_count++;
			}
			$html       .= '  </tr>' . "\n";
		}
		$html .= '</table>' . "\n";

		return $html;
	}

	sub _build_header {
		my ( $self ) = @_;
		my $fields   = $self->get_fields();
		my $html .= '  <tr>' . "\n";
		if ( $self->delete_enabled() ) {
			$html   .= '    <td valign="top" class="browseHead"> &nbsp; </td>' . "\n";
		}
		foreach my $field ( @$fields ) { 
			if (! $field->{hide} ) {
				if ( $field->{sort} ) {
					$html .= '    <td valign="top" class="browseHead"> <a class="browseHead" href="javascript:browseSort(\'' . $field->{name} . '\');">' . $field->{label} . '</a> </td>' . "\n"; 
				} else {
					$html .= '    <td valign="top" class="browseHead"> ' . $field->{label} . '</td>' . "\n"; 
				}
			}
		}
		$html .= '  </tr>' . "\n";
		return $html;
	}

	sub _build_sorted {
		my ( $self ) = @_;
		my $sort     = $self->get_sort();   
		   $sort     =~ s/_/ /g;
		   $sort     = $sort ? $sort : 'default';
		return '<font class="browseInfo"> Sorted by ' . $sort . '.</font>';
	}

	sub _build_start {
		my ( $self ) = @_;
		my $count    = $self->get_count();
		my $index    = $self->get_index();
		return '<font class="browseInfo"> Starting row ' . $self->commify($index + 1) . ' / ' . $self->commify($count) . '.</font>';
	}

	sub _build_prev_next {
		my ( $self ) = @_;
		my $window   = $self->get_window();
		my $index    = $self->get_index();
		my $count    = $self->get_count();
		my ( $pindex, $nindex, $html );

	  	if ($index > 0) {
	    		if ($index - $window > 0) { $pindex = $index - $window; } else { $pindex = 0; }
	    		$html .= '      <a class="browsePrevNextOn" href="javascript:browseSetIndex(\'' . $pindex . '\');">< Prev</a> | ';
	  	} else {
	    		$html .= '      <font class="browsePrevNextOff">< Prev</font> | ';
	  	}
	
		# Next rows
		if ($index + $window < $count) {
			$nindex = $index + $window;
	    		$html .= '<a class="browsePrevNextOn" href="javascript:browseSetIndex(\'' . $nindex . '\');">Next ></a> ';
		} else {
			$html .= '<font class="browsePrevNextOff">Next ></font>';
		}
		return $html;
	}

	sub _build_show {
		my ( $self ) = @_;
		my $window   = $self->get_window();
		my $html     = '<font class="browseInfo">Show <input class="browseSmallBox" size="4" type="text" name="window" id="window" value="' .$window . '"> rows.</font> <input type="submit" class="browseSmallButton" value="Submit">';
		return $html;
	}

	sub _build_goto {
		my ( $self ) = @_;
		my $window   = $self->get_window();
		my $count    = $self->get_count();
		my $index    = 0;
		my $page     = 0;
		my $html     = '<font class="browseInfo">Go to page</font><select class="browseSmallSelect" name="page" id="page">';
		while ( $index < $count ) {
		   $html    .= '<option value="' . $index . '"> ' . ++$page . ' '; 
		   $index   += $window; 
		}
		$html       .= '</select>. <input type="button" onclick="browseSetIndex(document.getElementById(\'page\').options[document.getElementById(\'page\').selectedIndex].value);" class="browseSmallButton" value="Submit">';
		return $html;
	}

	sub _build_control {
		my ( $self ) = @_;
		my $index    = $self->get_index();
		my $sort     = $self->get_sort();
		my $sort_vec = $self->get_sort_vec();
		my $html     = '<input type="hidden" name="index" id="index" value="' . $index . '">';
		   $html    .= '<input type="hidden" name="sort" id="sort" value="' . $sort . '">';
		   $html    .= '<input type="hidden" name="sort_vec" id="sort_vec" value="'. $sort_vec . '">';
		if ( $self->delete_enabled() ) {
		   $html    .= '<input type="hidden" name="delete_ids" id="delete_ids" value="">';
		}
		return $html;
	}

	sub _build_delete {
		my ( $self ) = @_;
		my $html;
		if ( $self->delete_enabled() eq 'multi' ) {
			my $url  = $self->get_urls()->{root} .  $self->get_urls()->{delete};
			$html = '<input type="button" onclick="browseDelete();" class="browseSmallButton" value="Delete selected">';
		}
		return $html;
	}

	sub _build_default_html {
		my ( $self, $build ) = @_;
		my $html  = $build->{browse_script};
		   $html .= '<form name="browse" action="' . $build->{browse_action} . '" method="POST">' . "\n";
		   $html .= '<table cellspacing="0" cellpadding="0" width="100%">' . "\n";
		   $html .= '  <tr>' . "\n";
		   $html .= '    <td align="left" width="36%"> &nbsp; &nbsp; ' . $build->{browse_sorted} . ' </td>' . "\n";
		   $html .= '    <td align="center" width="34%">' . $build->{browse_start} . '</td>' . "\n";
		   $html .= '    <td align="right" width="30%">' . $build->{browse_prevnext} . '</td>' . "\n";
		   $html .= '  </tr>' . "\n";
		   $html .= '</table>' . "\n";
		   $html .= $build->{browse_table};
		   $html .= '&nbsp; <br>' . "\n";
		   $html .= '<table border="0" cellspacing="0" cellpadding="0" width="100%">' . "\n";
		   $html .= '  <tr>' . "\n";
		   $html .= '    <td width="36%">' . $build->{browse_show} . '</td>' . "\n";
		   $html .= '    <td width="34%">' . $build->{browse_delete} . '</td>' . "\n";
		   $html .= '    <td width="30%" align="right">' . $build->{browse_goto} . '</td>' . "\n";
		   $html .= '  </tr>' . "\n";
		   $html .= '  <tr>' . "\n";
		   $html .= '    <td colspan="2">' . $build->{browse_control} . '</td>' . "\n";
		   $html .= '  </tr>' . "\n";
		   $html .= '</table>' . "\n";
		   $html .= '</form>' . "\n";
		return $html;
	}

	sub _get_rows {
		my ( $self, $arg_ref ) = @_;
		my $sql = $self->build_sql( $arg_ref );
		return $self->dbh()->sqlexec( $sql, '\@@' );
	}

	sub _get_row_count {
		my ( $self, $arg_ref ) = @_;
		my $sql = $self->build_sql( $arg_ref );
		   $sql =~ s/select (.*) from/select count(*) from/g;
		   $sql =~ s/limit.*$//g;
		my ( $row_count ) = $self->dbh()->sqlexec( $sql, '@' );
		return $row_count;
	}

	sub commify {
		my ( $self, $value ) = @_;
		my $text = reverse $value;
		$text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
		return scalar reverse $text;
	}

	sub flip_sort_vec {
		my ( $self ) = @_;
		my $ident    = ident $self;
		my $sort_vec = $sort_vec_of{$ident};
		if ( $sort_vec eq 'asc' ) { $sort_vec = 'desc'; } else { $sort_vec = 'asc'; } 
		$self->set_sort_vec( $sort_vec );
		return $sort_vec;
	}
}

1; # Magic true value required at end of module
__END__

=head1 NAME

IOSea::Browse - Build HTML table to display rows with flexible delete and multi-links for edit.

=head1 VERSION

This document describes IOSea::Browse version 1.0.0

=head1 SYNOPSIS

The Browse object can be used with the default HTML layout, which includes all of the features.

    use IOSea::Browse;

    # Get CGI variables using favorite method
    
    # Define table fields
    my $fields      = [ { name   => 'state_capital_id', label => 'ID',            
                          hide => 1, sort => 0 },
                        { name   => 'state',            label => 'State',         
			  hide => 0, sort => 1, link => 'link1', id => 0 },
                        { name   => 'statehood_year',   label => 'Statehood',     
			  hide => 0, sort => 1 },
                        { name   => 'capital',          label => 'Capital',       
			  hide => 0, sort => 1, link => 'link2', id => 0 },
                        { name   => 'capital_since',    label => 'Capital Since', 
			  hide => 0, sort => 1 },
                        { name   => 'most_populous',    label => 'Most Populous', 
			  hide => 0, sort => 1 },
                        { name   => 'city_population',  label => 'City Pop.',     
			  hide => 0, sort => 1 },
                        { name   => 'metro_population', label => 'Metro Pop.',    
			  hide => 1, sort => 1 },
                        { name   => 'notes',            label => 'Notes',         
			  hide => 0, sort => 0 } ];
    
    # Define browse parameters (including fields and matchin SQL statement)
    my $params      = { fields   => $fields,
                        sql      => "select state_capital_id, state, statehood_year, capital, capital_since, most_populous, city_population, metro_population, notes from state_capitals",
                        connect  => { db   => 'mydb', host => 'localhost', user => 'user', pass => 'pass' },
                        urls     => { root => 'http://bioinformatics.ualr.edu/', browse => 'cgi-bin/eg/browse.cgi', link1 => 'cgi-bin/eg/browse_link1.cgi?id=', link2 => 'cgi-bin/eg/browse_link2.cgi?id=', delete => 'cgi-bin/eg/browse_delete.cgi?id=' },
                        classes  => ['browseRowA', 'browseRowA', 'browseRowA', 'browseRowB', 'browseRowB', 'browseRowB'],
                        features => { default_html => 1, delete => 'each' } };

    # Create the browse object
    my $browse      = IOSea::Browse->new( $params );
    
    # Build HTML page
    my $html  = "Content-type: text/html\n";
       $html .= "Status: 200 OK \n\n";
       $html .= "<html>\n";
       $html .= "<head>\n";
       $html .= "  <title>IOSea::Browse Module Sample Script</title>\n";
       $html .= $browse->_build_styles(); # Defines included styles
       $html .= "</head>\n";
       $html .= "<body>\n";
       $html .= $browse->build( \%cgi_vars );
       $html .= "</body>\n";
       $html .= "</html>\n";
    
    # Print page
    print $html;
    
It can also be used with a Template system (such as Template Toolkit) by removing the "default_html" feature.


    use Template;
    use IOSea::Browse;

    ...
    
    my $params      = { fields   => $fields,
                        sql      => "select state_capital_id, state, statehood_year, capital, capital_since, most_populous, city_population, metro_population, notes from state_capitals",
                        connect  => { db   => 'dev', host => 'localhost', user => 'root', pass => 'binf.452e' },
                        urls     => { root => 'http://bioinformatics.ualr.edu/', browse => 'cgi-bin/eg/browse_tmpl.cgi', link1 => 'cgi-bin/eg/browse_link1.cgi?id=', link2 => 'cgi-bin/eg/browse_link2.cgi?id=', delete => 'cgi-bin/eg/browse_delete.cgi' },
                        classes  => ['browseRowA', 'browseRowA', 'browseRowA', 'browseRowB', 'browseRowB', 'browseRowB'],
                        features => { delete => 'multi' } };

    my $browse      = IOSea::Browse->new( $params );
    my $build       = $browse->build( \%cgi_vars );
    my $template    = Template->new();
       $template->process( \$tmpl, $build );
    
=head1 DESCRIPTION

The Browse object is a flexible component for listing data in an HTML table.

=head3 FIELDS 

It requires a fields list and a SQL statement to define the data. Field options include:

=over

=item name

This is the SQL field name. It is used in conjuction with sort to reorder the table. It is also used in the "Sorted by" label feature.

=item label

This is the header label. It doesn't have to match the database. It will be clickable if sort is TRUE.

=item hide

This setting is optional for all fields. If TRUE, it will keep Browse from displaying the column. This is useful for keys/foreign keys that are included for the purpose of linking to other screens.

=item sort

This setting enables the user to click on this column's heading (label) to resort the column. Repeatedly clicking the column heading alternates between ascending and descending sorts.

=item link

This setting defines a link-out for this column's data. There must also be a URL setting for the value of this link.

=item id

This setting defines which column's value is appended to the link-out URL. Note: this column should be included in the SQL statement.

=back

=head3 DELETE FEATURE 

There are two different delete methods available in addition to disabling the delete feature.

You can enable a delete per row:

    features => { default_html => 1, delete => 'each' } };

You can enable delete checkboxes with a "Delete selected" button:

    features => { default_html => 1, delete => 'multi' } };

You can disable delete by removing the delete key from the "features" parameter:

    features => { default_html => 1, delete => 'each' } };

=head1 INTERFACE 

The module has only one public method besides new().

=over

=item build()

=back

The following methods are considered private, but may be useful depending on your implementation.

=over

=item _build_styles()

=item _build_tmpl()

=back

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

IOSea::Browse requires no configuration files or environment variables.

=head1 DEPENDENCIES

    Class::Std
    Class::Std::Utils
    DBIx::MySperqlOO

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-iosea-browse@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 AUTHOR

Roger A Hall  C<< <rogerhall@cpan.org> >>
Michael Bauer  C<< <kodos@nmt.edu> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009, Roger A Hall C<< <rogerhall@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
