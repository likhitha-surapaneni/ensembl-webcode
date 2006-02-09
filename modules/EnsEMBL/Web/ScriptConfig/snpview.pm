package EnsEMBL::Web::ScriptConfig::snpview;

use strict;
no strict 'refs';

sub init {
  my ($script_config ) = @_;

  $script_config->_set_defaults(qw(
    panel_genotypes  on
    panel_alleles    on
    panel_locations  on
    panel_individual off
    image_width      600

    opt_non_synonymous_coding  on
    opt_frameshift_coding      on
    opt_synonymous_coding      on
    opt_5prime_utr             on
    opt_3prime_utr             on
    opt_intronic               on
    opt_downstream             on
    opt_upstream               on
    opt_intergenic             on
    opt_essential_splice_site  on
    opt_splice_site            on
    opt_regulatory_region      on
    opt_stop_gained            on
    opt_stop_lost              on



  ));
}
1;
