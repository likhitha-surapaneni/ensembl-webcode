package EnsEMBL::Web::Component::Transcript::SimilarityMatches;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
our @EXPORT = qw(_sort_similarity_links _matches);  ##dunno if this is needed

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object   = $self->object;

  my $html =  _matches( $object, 'similarity_matches', 'Similarity Matches', 'PRIMARY_DB_SYNONYM', 'MISC' );

return $html;
}
sub _flip_URL {
  my( $transcript, $code ) = @_;
  return sprintf '/%s/%s?transcript=%s;db=%s;%s', $transcript->species, $transcript->script, $transcript->stable_id, $transcript->get_db, $code;
}

sub _matches {
  my(  $transcript, $key, $caption, @keys ) = @_;
  my $label = $transcript->species_defs->translate( $caption );
  my $trans = $transcript->transcript;
  # Check cache

  unless ($transcript->__data->{'links'}){
    my @similarity_links = @{$transcript->get_similarity_hash($trans)};
    return unless (@similarity_links);
    _sort_similarity_links($transcript, @similarity_links);
  }

  my $URL = _flip_URL( $transcript, "status_$key" );
  if( $transcript->param( "status_$key" ) eq 'off' ) {
    #$panel->add_row( $label, '', "$URL=on" );
    return 0;
  }

  my @links = map { @{$transcript->__data->{'links'}{$_}||[]} } @keys;
  return unless @links;

  my $db = $transcript->get_db();
  my $entry = $transcript->gene_type || 'Ensembl';

  # add table call here
  my $html;
  if ($transcript->species_defs->ENSEMBL_SITETYPE eq 'Vega') {
    $html = qq(<p></p>);
  }
  else {
    $html = qq(<p><strong>This $entry entry corresponds to the following database identifiers:</strong></p>);
  }
  $html .= qq(<table cellpadding="4">);
  if( $keys[0] eq 'ALT_TRANS' ) {
    @links = &remove_redundant_xrefs(@links);
  }
  my $old_key = '';
  foreach my $link (@links) {
    my ( $key, $text ) = @$link;
    if( $key ne $old_key ) {
      if($old_key eq "GO") {
        $html .= qq(<div class="small">GO mapping is inherited from swissprot/sptrembl</div>);
      }
      if( $old_key ne '' ) {
        $html .= qq(</td></tr>);
      }
      $html .= qq(<tr><th style="white-space: nowrap; padding-right: 1em">$key:</th><td>);
      $old_key = $key;
    }
    $html .= $text;
  }
  $html .= qq(</td></tr></table>);

return $html;
}


#this is temporarily needed to delete duplicated and redundant database entries
#used for both core and ensembl-vega databases
sub remove_redundant_xrefs {
  my (@links) = @_;
  my %priorities;
  foreach my $link (@links) {
    my ( $key, $text ) = @$link;
    if ($text =~ />OTT|>ENST/) {
      $priorities{$key} = $text;
    }
  }
  foreach my $type (
    'Transcript having exact match between ENSEMBL and HAVANA',
    'Ensembl transcript having exact match with Havana',
    'Havana transcript having same CDS',
    'Ensembl transcript sharing CDS with Havana',
    'Havana transcripts') {
    if ($priorities{$type}) {
      my @munged_links;
      $munged_links[0] = [ $type, $priorities{$type} ];
      return @munged_links;;
    }
  }
  return @links;
}

sub _sort_similarity_links{
  my $object = shift;
  my @similarity_links = @_;
  my $database = $object->database;
  my $db       = $object->get_db() ;
  my $urls     = $object->ExtURL;
  my @links ;
  my (%affy, %exdb);
  # @ice names    
  foreach my $type (sort {
    $b->priority        <=> $a->priority ||
    $a->db_display_name cmp $b->db_display_name ||
    $a->display_id      cmp $b->display_id
  } @similarity_links ) {
    my $link = "";
    my $join_links = 0;
    my $externalDB = $type->database();
    my $display_id = $type->display_id();
    my $primary_id = $type->primary_id();
    next if ($type->status() eq 'ORTH');               # remove all orthologs   
    next if lc($externalDB) eq "medline";              # ditch medline entries - redundant as we also have pubmed
    next if ($externalDB =~ /^flybase/i && $display_id =~ /^CG/ ); # Ditch celera genes from FlyBase
    next if $externalDB eq "Vega_gene";                # remove internal links to self and transcripts
    next if $externalDB eq "Vega_transcript";
    next if $externalDB eq "Vega_translation";
    if( $externalDB eq "GO" ){
      push @{$object->__data->{'links'}{'go'}} , $display_id;
      next;
    } elsif ($externalDB eq "GKB") {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'links'}{'gkb'}->{$key}} , $type ;
      next;
    }
 my $text = $display_id;
    (my $A = $externalDB ) =~ s/_predicted//;
    if( $urls and $urls->is_linked( $A ) ) {
      my $link;
      $link = $urls->get_url( $A, $primary_id );

      my $word = $display_id;
      if( $A eq 'MARKERSYMBOL' ) {
        $word = "$display_id ($primary_id)";
      }
      if( $link ) {
        $text = qq(<a href="$link">$word</a>);
      } else {
        $text = qq($word);
      }
    }
#    warn $externalDB;
#    warn $type->db_display_name;
    if( $type->isa('Bio::EnsEMBL::IdentityXref') ) {
      $text .=' <span class="small"> [Target %id: '.$type->target_identity().'; Query %id: '.$type->query_identity().']</span>';
      $join_links = 1;
    }
    if( ( $object->species_defs->ENSEMBL_PFETCH_SERVER ) &&
      ( $externalDB =~/^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i ) ) {
      my $seq_arg = $display_id;
      $seq_arg = "LL_$seq_arg" if $externalDB eq "LocusLink";
      $text .= sprintf( ' [<a href="/%s/alignview?transcript=%s;sequence=%s;db=%s">align</a>] ',
                  $object->species, $object->stable_id, $seq_arg, $db );
    }
    if($externalDB =~/^(SWISS|SPTREMBL)/i) { # add Search GO link            
      $text .= ' [<a href="'.$urls->get_url('GOSEARCH',$primary_id).'">Search GO</a>]';
    }
    if( $type->description ) {
      ( my $D = $type->description ) =~ s/^"(.*)"$/$1/;
      $text .= "<br />".CGI::escapeHTML($D);
      $join_links = 1;
    }
 if( $join_links  ) {
      $text = qq(\n  <div>$text</div>);
    } else {
      $text = qq(\n  <div class="multicol">$text</div>);
    }
    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if( $externalDB =~ /^AFFY_/i) {
      next if ($affy{$display_id} && $exdb{$type->db_display_name}); ## remove duplicates
      $text = "\n".'  <div class="multicol"><a href="' .$urls->get_url('AFFY_FASTAVIEW', $display_id) .'">'. $display_id. '</a></div>';
      $affy{$display_id}++;
      $exdb{$type->db_display_name}++;
    }
    push @{$object->__data->{'links'}{$type->type}}, [ $type->db_display_name || $externalDB, $text ] ;
#    warn $text;
  }
#  return $object->__data->{'similarity_links'};
}


#this is temporarily needed to delete duplicated and redundant database entries
#used for both core and ensembl-vega databases
#should be largely redundant with new schema databases
sub remove_redundant_xrefs {
	my (@links) = @_;
	my %priorities;
	foreach my $link (@links) {
		my ( $key, $text ) = @$link;
		if ($text =~ />OTT|>ENST/) {
			$priorities{$key} = $text;
		}
	}
	foreach my $type (
		'Transcript having exact match between ENSEMBL and HAVANA',
		'Ensembl transcript having exact match with Havana',
		'Havana transcript having same CDS',
		'Ensembl transcript sharing CDS with Havana',
		'Havana transcripts') {
		if ($priorities{$type}) {
			my @munged_links;
			$munged_links[0] = [ $type, $priorities{$type} ];
			return @munged_links;;
		}
	}
	return @links;
}


1;


