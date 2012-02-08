package EnsEMBL::Web::Component::UserData::SelectReportOptions;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Select Output Options';
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my $html;

  my $sitename = $hub->species_defs->ENSEMBL_SITETYPE;
  my $current_species = $hub->data_species;

  my $form = $self->modal_form('select', $hub->species_path($current_species) . "/UserData/CheckRegions", {'label'=>''});

  if (!$hub->param('filter_module')) { ## No errors
    $form->add_notes({'id' => 'upload_notes', 'heading' => 'IMPORTANT NOTE', 'text' => qq{
      This web tool is only suitable for exporting a limited dataset: a maximum of <strong>5 megabases</strong> total input is allowed (1 megabase if variation or regulation is selected).<br /> 
 If you wish to produce a report based on many regions or regions with dense data, we recommend using the standalone <a href="/tools.html">API script</a>
    }});
  }

  $form->add_element( type => 'String', name => 'name', label => 'Name for this report (optional)' );

  ## Species is set automatically for the page you are on
  my @species;
  foreach my $sp ($hub->species_defs->valid_species) {
    push @species, {'value' => $sp, 'name' => $hub->species_defs->species_label($sp, 1)};
  }
  @species = sort {$a->{'name'} cmp $b->{'name'}} @species;
  $form->add_element(
      'type'    => 'DropDown',
      'name'    => 'species',
      'label'   => "Species",
      'values'  => \@species,
      'value'   => $current_species,
      'select'  => 'select',
  );

  my $sample_region = $hub->param('r') || '6:133017695-133161157';
  $form->add_element( type => 'Text', name => 'text', label => 'Paste region coordinates', 'notes' => 'One set of coordinates per line', 'value' => $sample_region);
  $form->add_element( type => 'File', name => 'file', label => 'Upload file' );
  $form->add_element( type => 'URL',  name => 'url',  label => 'or provide file URL', size => 30 );

  my $features = [
    {'value' => 'gt', 'caption' => 'Genes, Transcripts and Proteins'},
    {'value' => 'q', 'caption' => 'Genomic Sequence'},
    {'value' => 'c', 'caption' => 'Constrained Elements (Conserved Regions)'},
    {'value' => 'v', 'caption' => 'Variations (SNPs and InDels)'},
    {'value' => 's', 'caption' => 'Structural Variations (CNVs etc)'},
    {'value' => 'r', 'caption' => 'Regulatory Features'},
  ];

  $form->add_element(
      'type'    => 'Checklist',
      'name'    => 'include',
      'label'   => 'Features',
      'value'   => 'gt',
      'values'  => $features,
  );

  $form->add_element(
      'type'      => 'Radiolist',
      'name'      => 'format',
      'label'     => 'Output format',
      'value'     => 'report',
      'values'    => [
                      {'value' => 'gff3',   'caption' => 'GFF3'}, 
                      {'value' => 'report', 'caption'  => 'Ensembl Region Report'}
                      ],
  );

  $html .= $form->render;
  
  return $html;
}

1;
