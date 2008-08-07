package EnsEMBL::Web::Configuration;

use strict;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::DASConfig;
use base qw(EnsEMBL::Web::Root);
our @ISA = qw(EnsEMBL::Web::Root);

use POSIX qw(floor ceil);
use CGI qw(escape);
use warnings;

sub object { 
  return $_[0]->{'object'};
}
sub populate_tree {

}
sub set_default_action {

}
sub new {
  my( $class, $page, $object, $flag, $common_conf ) = @_;
  my $self = {
    'page'    => $page,
    'object'  => $object,
    'flag '   => $flag || '',
    'cl'      => {},
    '_data'   => $common_conf
  };
  bless $self, $class;
  $self->populate_tree;
  $self->set_default_action;
  return $self;
}

sub tree {
  my $self = shift;
  return $self->{_data}{tree};
}

sub configurable {
  my $self = shift;
  return $self->{_data}{configurable};
}

sub action {
  my $self = shift;
  return $self->{_data}{'action'};
}
sub set_action {
  my $self = shift;
  $self->{_data}{'action'} = $self->_get_valid_action(shift);
}

sub default_action {
### Default action for feature type...
  my $self = shift;
  unless( $self->{_data}{'default'} ) {
    ($self->{_data}{'default'}) = $self->{_data}{tree}->leaf_codes;
  }
  return $self->{_data}{'default'};
}

sub _get_valid_action {
  my $self = shift;
  my $action = shift;
  my %hash = map { $_ => 1 } $self->{_data}{tree}->leaf_codes;
  return exists( $hash{$action} ) ? $action : $self->default_action;
}

sub _ajax_content {
  my $self   = shift;
  my $obj    = $self->{'object'};
  $self->{'page'}->renderer->{'r'}->headers_in->{'X-Requested-With'} = 'XMLHttpRequest';
## Force page type to be ingredient!
  $self->{'page'}->{'_page_type_'} = 'ingredient';
  my $panel  = $self->new_panel( 'Ajax', 'code' => 'ajax_panel', 'object'   => $obj);
  $panel->add_component( 'component' => $ENV{'ENSEMBL_ACTION'} );
  $self->add_panel( $panel );
}

sub _ajax_zmenu {
  my $self   = shift;
  my $obj    = $self->{'object'};
  $self->{'page'}->renderer->{'r'}->headers_in->{'X-Requested-With'} = 'XMLHttpRequest';
  my $panel  = $self->new_panel( 'AjaxMenu', 'code' => 'ajax_zmenu', 'object'   => $obj );
  $self->add_panel( $panel );
  return $panel;
}

sub _global_context {
  my $self = shift;
  my $type = $self->type;
  return unless $self->{object}->core_objects;

  my @data = (
    ['location',  'Location',   $self->{object}->core_objects->location_short_caption ],
    ['gene',      'Gene',       $self->{object}->core_objects->gene_short_caption ],
    ['transcript','Transcript', $self->{object}->core_objects->transcript_short_caption ],
    ['variation',       'Variation',  $self->{object}->core_objects->variation_short_caption ],
  );
  my $qs = $self->query_string;
  foreach my $row ( @data ) {
    next if $row->[2] eq '-';
    my $url   = "/$ENV{ENSEMBL_SPECIES}/$row->[1]/Summary?$qs";
    my @class = ();
    if( $row->[1] eq $type ) {
      push @class, 'active';
    }
    $self->{'page'}->global_context->add_entry( 
      'type'      => $row->[1],
      'caption'   => $row->[2],
      'url'       => $url,
      'class'     => (join ' ',@class),
    );
  }
  $self->{'page'}->global_context->active( lc($type) );
}

sub _user_context {
  my $self = shift;
  my $type = $self->type;

  my @data = (
    ['config',    'Config',   'Configure Page' ],
    ['userdata',  'UserData', 'Custom Data' ],
  );
  if ($self->{object}->species_defs->ENSEMBL_LOGINS) {
    push @data, ['account',   'Account',  'Your Account' ];
  }
  my $qs = $self->query_string;
  foreach my $row ( @data ) {
    next if $row->[2] eq '-';
    my $url;
    my $species = $ENV{ENSEMBL_SPECIES};
    if ($species && $species ne 'common') {
      $url .= "/$species";
    }   
    $url .= "/$row->[1]/Summary?$qs";
    my @class = ();
    if( $row->[1] eq $type ) {
      push @class, 'active';
    }
    $self->{'page'}->global_context->add_entry( 
      'type'      => $row->[1],
      'caption'   => $row->[2],
      'url'       => $url,
      'class'     => (join ' ',@class),
    );
  }
  $self->{'page'}->global_context->active( lc($type) );
}

sub _local_context {
  my $self = shift;
  my $hash = {}; #  $self->obj->get_summary_counts;
  $self->{'page'}->local_context->tree(    $self->{_data}{'tree'}    );
  $self->{'page'}->local_context->active(  $self->{_data}{'action'}  );
  $self->{'page'}->local_context->caption( $self->{object}->short_caption  );
  $self->{'page'}->local_context->counts(  $self->{object}->counts   );
}

sub _local_tools {
  my $self = shift;
  my $obj = $self->{object};

  my @data = (
    ['Bookmark this page',  '/Account/Bookmark', 'modal_link' ],
  );
  if ($self->configurable) {
    push @data, ['Configure this page',     '/sorry.html', 'modal_link' ];
  }

  push @data, ['Export Data',     '/sorry.html', 'modal_link' ];

  my $type;
  foreach my $row ( @data ) {
    if( $row->[1] =~ /^http/ ) {
      $type = 'external';
    }
    $self->{'page'}->local_tools->add_entry(
      'type'      => $type,
      'caption'   => $row->[0],
      'url'       => $row->[1],
      'class'     => $row->[2]
    );
  }
}

sub _user_tools {
  my $self = shift;
  my $obj = $self->{object};

  my $sitename = $obj->species_defs->ENSEMBL_SITETYPE;
  my @data = (
          ['Back to '.$sitename,   '/index.html'],
  );

  my $type;
  foreach my $row ( @data ) {
    if( $row->[1] =~ /^http/ ) {
      $type = 'external';
    }
    $self->{'page'}->local_tools->add_entry(
      'type'      => $type,
      'caption'   => $row->[0],
      'url'       => $row->[1],
    );
  }
}

sub _context_panel {
  my $self   = shift;
  my $obj    = $self->{'object'};
  my $panel  = $self->new_panel( 'Summary',
    'code'     => 'summary_panel',
    'object'   => $obj,
    'caption'  => $obj->caption
  );
  $panel->add_component( 'summary' => sprintf( 'EnsEMBL::Web::Component::%s::Summary', $self->type ) );
  $self->add_panel( $panel );
}

sub _content_panel {
  my $self   = shift;
  my $obj    = $self->{'object'};

  my $action = $self->_get_valid_action( $ENV{'ENSEMBL_ACTION'} );
  my $node          = $self->get_node( $action );
  my $title = $node->data->{'concise'}||$node->data->{'caption'};
     $title =~ s/\s*\(.*\[\[.*\]\].*\)\s*//;
     $title = join ' - ', '', ( $obj ? $obj->caption : () ), $title;
  $self->set_title( $title );

  my ($previous_node,$next_node);
  #don't show tabs for 'no_menu' nodes
  if ($previous_node = $node->previous_leaf) {
      while ($previous_node->data->{'no_menu_entry'}) {
	  $previous_node = $previous_node->previous_leaf;
      }
  }
  if ($next_node     = $node->next_leaf ) {
      while ($next_node->data->{'no_menu_entry'}) {
	  $next_node = $next_node->next_leaf;
      }
  }

  my %params = (
    'object'   => $obj,
    'code'     => 'main',
    'caption'  => $node->data->{'concise'} || $node->data->{'caption'}
  );
  $params{'previous'} = $previous_node->data if $previous_node;
  $params{'next'    } = $next_node->data     if $next_node;

  if ($self->{doctype} eq 'Popup') {
    $params{'omit_header'} = 1;
  }
  my $panel = $self->new_panel( 'Navigation', %params );
  if( $panel ) {
    $panel->add_components( @{$node->data->{'components'}} );
    $self->add_panel( $panel );
  }
}

sub get_node { 
  my ( $self, $code ) = @_;
  return $self->{_data}{tree}->get_node( $code );
}

sub species { return $ENV{'ENSEMBL_SPECIES'}; }
sub type    { return $ENV{'ENSEMBL_TYPE'}; }
sub query_string {
  my $self = shift;
  return unless defined $self->{object}->core_objects;
  my %parameters = (%{$self->{object}->core_objects->{parameters}},@_);
  my @S = ();
  foreach (sort keys %parameters) {
    push @S, "$_=$parameters{$_}" if defined $parameters{$_}; 
  }
  push @S, '_referer='.CGI::escape($self->object->param('_referer'))
    if $self->object->param('_referer');
  return join ';', @S;
}

sub create_node {
  my ( $self, $code, $caption, $components, $options ) = @_;
 
  my $url = '/';
  if ($self->species && $self->species ne 'common') {
    $url .= $self->species.'/';
  }
  $url .= $self->type.'/'.$code;
  if ($self->query_string) {
    $url .= '?'.$self->query_string;
  }
 
  my $details = {
    'caption'    => $caption,
    'components' => $components,
    'url'        => $url, 
  };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  return $self->tree->create_node( $code, $details );
}

sub create_submenu {
  my ($self, $code, $caption, $options ) = @_;
  my $details = { 'caption'    => $caption, 'url' => '' };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  return $self->tree->create_node( $code, $details );
}

sub update_configs_from_parameter {
  my( $self, $parameter_name, @userconfigs ) = @_;
  my $val = $self->{object}->param( $parameter_name );
  my $rst = $self->{object}->param( 'reset' );
  my $wsc = $self->{object}->get_scriptconfig();
  my @das = $self->{object}->param( 'add_das_source' );

  foreach my $config_name ( @userconfigs ) {
    $self->{'object'}->attach_image_config( $self->{'object'}->script, $config_name );
    $self->{'object'}->user_config_hash( $config_name );
  }
  foreach my $URL ( @das ) {
    my $das = EnsEMBL::Web::DASConfig->new_from_URL( $URL );
    $self->{object}->get_session( )->add_das( $das );
  }
  return unless $val || $rst;
  if( $wsc ) {
    $wsc->reset() if $rst;
    $wsc->update_config_from_parameter( $val ) if $val;
  }
  foreach my $config_name ( @userconfigs ) {
    my $wuc = $self->{'object'}->user_config_hash( $config_name );
#    my $wuc = $self->{'object'}->get_userconfig( $config_name );
    if( $wuc ) {
      $wuc->reset() if $rst;
      $wuc->update_config_from_parameter( $val ) if $val;
      $self->{object}->get_session->_temp_store( $self->{object}->script, $config_name );
    }
  }
}

sub add_panel { $_[0]{page}->content->add_panel( $_[1] ); }
sub set_title { $_[0]{page}->set_title( $_[1] ); }
sub add_form  { my($self,$panel,@T)=@_; $panel->add_form( $self->{page}, @T ); }

sub wizard {
### a
  my ($self, $wizard) = @_;
  if ($wizard) {
    $self->{'wizard'} = $wizard;
  }
  return $self->{'wizard'};
}


sub add_block {
  my $self = shift;
  return unless $self->{page}->can('menu');
  return unless $self->{page}->menu;
  my $flag = shift;
  $flag =~s/#/($self->{flag} || '')/ge;
#     $flag =~s/#/$self->{flag}/g;
  $self->{page}->menu->add_block( $flag, @_ );
}

sub delete_block {
  my $self = shift;
  return unless $self->{page}->can('menu');
  return unless $self->{page}->menu;
  my $flag = shift;
     $flag =~s/#/$self->{flag}/g;
  $self->{page}->menu->delete_block( $flag, @_ );
}

sub add_entry {
  my $self = shift;
  return unless $self->{page}->can('menu');
  return unless $self->{page}->menu;
  my $flag = shift;
  $flag =~s/#/($self->{flag} || '')/ge;
  $self->{page}->menu->add_entry( $flag, @_ );
}

sub new_panel {
  my( $self, $panel_type, %params ) = @_;
  my $module_name = "EnsEMBL::Web::Document::Panel";
     $module_name.= "::$panel_type" if $panel_type;
  $params{'code'} =~ s/#/$self->{'flag'}||0/eg;
  if( $panel_type && !$self->dynamic_use( $module_name ) ) {
    my $error = $self->dynamic_use_failure( $module_name );
    my $message = "^Can't locate EnsEMBL/Web/Document/Panel/$panel_type\.pm in";
    if( $error =~ m:$message: ) {
      $error = qq(<p>Unrecognised panel type "<b>$panel_type</b>");
    } else {
      $error = sprintf( "<p>Unable to compile <strong>$module_name</strong></p><pre>%s</pre>",
                $self->_format_error( $error ) );
    }
    $self->{page}->content->add_panel(
      new EnsEMBL::Web::Document::Panel(
        'object'  => $self->{'object'},
        'code'    => "error_$params{'code'}",
        'caption' => "Panel compilation error",
        'content' => $error,
        'has_header' => $params{'has_header'},
      )
    );
    return undef;
  }
  no strict 'refs';
  my $panel;
  eval {
    $panel = $module_name->new( 'object' => $self->{'object'}, %params );
  };
  return $panel unless $@;
  my $error = "<pre>".$self->_format_error($@)."</pre>";
  $self->{page}->content->add_panel(
    new EnsEMBL::Web::Document::Panel(
      'object'  => $self->{'object'},
      'code'    => "error_$params{'code'}",
      'caption' => "Panel runtime error",
      'content' => "<p>Unable to compile <strong>$module_name</strong></p>$error"
    )
  );
  return undef;
}

sub mapview_possible {
  my( $self, $location ) = @_;
  my @coords = split(':', $location);
  my %chrs = map { $_,1 } @{$self->{object}->species_defs->ENSEMBL_CHROMOSOMES || []};
  return 1 if exists $chrs{$coords[0]};
}

sub initialize_ddmenu_javascript {
  my $self = shift;
  $self->{page}->javascript->add_script( 'var LOADED = 0;' );
  $self->{page}->javascript->add_source( '/js/dd_menus_42.js' );
  $self->{page}->add_body_attr( 'onLoad' => 'LOADED = 1;' );
}

sub initialize_zmenu_javascript {
  my $self = shift;
  $self->{page}->javascript->add_script( 'var LOADED = 0;' );
  $self->{page}->javascript->add_source( '/js/zmenu_42.js' );
  $self->{page}->javascript_div->add_div( 'jstooldiv', { 'style' => 'z-index: 200; position: absolute; visibility: hidden' } , '' );
  $self->{page}->add_body_attr( 'onLoad' => 'LOADED = 1;' );
}

sub initialize_zmenu_javascript_new {
  my $self = shift;
  #warn "sr7:initialise_zmenu_javascript_new is called\n";
  $self->{page}->javascript->add_script( 'var LOADED = 0;' );
  foreach( qw(dd_menus_42.js new_contigview_support_42.js new_drag_imagemap.js new_old_zmenu_42.js new_zmenu_42.js new_support.js protopacked.js) ) {
    $self->{page}->javascript->add_source( "/js/$_" );
  }
  $self->{page}->javascript_div->add_div( 'jstooldiv', { 'style' => 'z-index: 200; position: absolute; visibility: hidden' } , '' );
  $self->{page}->add_body_attr( 'onLoad' => 'LOADED = 1;' );
}

sub context_location {
  my $self = shift;
  my $obj = $self->{object};
  return unless $obj->can( 'location_string' );
  my $species = $obj->species;
  my( $q_string, $header ) = $obj->location_string;
  $header = "@{[$obj->seq_region_type_and_name]}<br />@{[$obj->thousandify(floor($obj->seq_region_start))]}";
  if( floor($obj->seq_region_start) != ceil($obj->seq_region_end) ) {
    $header .= " - @{[$obj->thousandify(ceil($obj->seq_region_end))]}";
  }
  my $flag = "location";
  $flag .= $self->{flag} if ($self->{flag});
  return if $self->{page}->menu->block($flag);
  my $no_sequence = $obj->species_defs->NO_SEQUENCE;
  if( $q_string ) {
    my $flag = "location";
    $flag .= $self->{flag} if ($self->{flag});
    $self->add_block( $flag, 'bulletted', $header, 'raw'=>1 ); ##RAW HTML!
    $header =~ s/<br \/>/ /;
    if( $self->mapview_possible( $obj->seq_region_name ) ) {
      $self->add_entry( $flag, 'text' => "View of @{[$obj->seq_region_type_and_name]}",
       'href' => "/$species/mapview?chr=".$obj->seq_region_name,
       'title' => 'MapView - show chromosome summary' );
    }
    unless( $no_sequence ) {
      $self->add_entry( $flag, 'text' => 'Graphical view',
        'href'=> "/$species/contigview?l=$q_string",
        'title'=> "ContigView - detailed sequence display of $header" );
    }
    $self->add_entry( $flag, 'text' => 'Graphical overview',
      'href'=> "/$species/cytoview?l=$q_string",
      'title' => "CytoView - sequence overview of $header" );
    unless( $no_sequence ) {
      $self->add_entry( $flag, 'text' => 'Export from region...',
        'title' => "ExportView - export information about $header",
        'href' => "/$species/exportview?l=$q_string"
      );
    # $self->add_entry( $flag, 'text' => 'Export sequence as FASTA',
    #   'title' => "ExportView - export sequence of $header as FASTA",
    #    'href' => "/$species/exportview?l=$q_string;format=fasta;action=format"
    # );
    #  $self->add_entry( $flag, 'text' => 'Export EMBL file',
    #   'title' => "ExportView - export sequence of $header as EMBL",
    #   'href' => "/$species/exportview?l=$q_string;format=embl;action=format"
    # );
    }
   unless ( $obj->species_defs->ENSEMBL_NOMART) {
      if( ${$obj->species_defs->multidb || {}}{'ENSEMBL_MART_ENSEMBL'} ) {
        $self->add_entry( $flag, 'icon' => '/img/biomarticon.gif' , 'text' => 'Export Gene info in region',
          'title' => "BioMart - export Gene information in $header",
          'href' => "/$species/martlink?l=$q_string;type=gene_region" );
      }
      if( ${$obj->species_defs->multidb || {}}{'ENSEMBL_MART_SNP'} ) {
        $self->add_entry( $flag, 'icon' => '/img/biomarticon.gif' , 'text' => 'Export SNP info in region',
          'title' => "BioMart - export SNP information in $header",
          'href' => "/$species/martlink?l=$q_string;type=snp_region" ) if $obj->species_defs->databases->{'ENSEMBL_VARIATION'};
      }
      if( ${$obj->species_defs->multidb || {}}{'ENSEMBL_MART_VEGA'} ) {
        $self->add_entry( $flag,  'icon' => '/img/biomarticon.gif' , 'text' => 'Export Vega info in region',
          'title' => "BioMart - export Vega gene features in $header",
          'href' => "/$species/martlink?l=$q_string;type=vega_region" ) if $obj->species_defs->databases->{'ENSEMBL_VEGA'};
      }
    }
  }
}

1;
