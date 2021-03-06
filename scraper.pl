#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use URI;

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URI of service.
my $base_uri = URI->new('http://www.sever.brno.cz/adresar-abecedne.html');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get base root.
print 'Page: '.$base_uri->as_string."\n";
my $root = get_root($base_uri);

# Table.
my $table = $root->find_by_tag_name('table');
my @tr = $table->find_by_tag_name('tr');
shift @tr;
foreach my $tr (@tr) {
	my @td = $tr->find_by_tag_name('td');
	my ($titul_pred, $jmeno, $prijmeni, $odbor, $klapka, $poznamka)
		= map {
			my $ret = $_->as_text;
			remove_trailing(\$ret);
			$ret = $ret =~ m/^\s*$/ms ? undef : $ret;
			$ret;
		} ($td[0], $td[1], $td[2], $td[3], $td[5], $td[6]);
	my $titul_za;
	if ($prijmeni =~ m/^(\w+),\s*([\w\.]+)$/ms) {
		$prijmeni = $1;
		$titul_za = $2;
	}
	# TODO E-mail
	
	# Save.
	print encode_utf8($jmeno.' '.$prijmeni)."\n";
	$dt->upsert({
		'Titul_pred' => $titul_pred,
		'Titul_za' => $titul_za,
		'Jmeno' => $jmeno,
		'Prijmeni' => $prijmeni,
		'Odbor' => $odbor,
		'E_mail' => undef,
		'Klapka' => $klapka,
		'Poznamka' => $poznamka,
	});
} 
$dt->create_index(['Jmeno', 'Prijmeni', 'Odbor'], undef, 'IF NOT EXISTS', 'UNIQUE');

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Removing trailing whitespace.
sub remove_trailing {
	my $string_sr = shift;
	${$string_sr} =~ s/^\s*//ms;
	${$string_sr} =~ s/\s*$//ms;
	return;
}
