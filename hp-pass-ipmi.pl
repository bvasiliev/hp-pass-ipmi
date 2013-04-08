#!/usr/bin/perl

use strict;
use SNMP::Extension::PassPersist;

my $base = ".1.3.6.1.4.1.39178.100.1.1.1.2.33";


# Update every 5 min
my $extsnmp = SNMP::Extension::PassPersist->new(
	backend_collect => \&update_tree,
	refresh         => 300
	);
$extsnmp->run;

sub extract_array {
	my @data_array = ("@_[1]", int(@_[3]*100)); # get name, value; *100 remove float
	return @data_array;
}

sub update_tree {
	my ($self) = @_;

	open(IPMI, "/tmp/ipmi.txt") or next;
	my @volts;
	my @fans;
	my @temps;
	my @parsed_ipmi;
	my $sensor_type;

	#read and parse file
	while (<IPMI>) {
		my $line = $_;
		# comma separate
		my @rows = split(',', $line);
		# if unit value exist
		if (@rows[3] != "N/A") {
			if (@rows[2] eq "Voltage") {
				my @volt = extract_array(@rows);
				push (@volts, [@volt]);
			}
			if (@rows[2] eq "Fan") {
				my @fan = extract_array(@rows);
				push (@fans, [@fan]);
			}
			if (@rows[2] eq "Temperature") {
				my @temp = extract_array(@rows);
				push (@temps, [@temp]);
			}
		}
	}
	close(IPMI); 
	
	#agregating parsed arrays of data in joint aray
	push (@parsed_ipmi, [@volts]);
	push (@parsed_ipmi, [@fans]);
	push (@parsed_ipmi, [@temps]);

	#generate oids from whole joint aray
	foreach (@parsed_ipmi) {	#for sensors block: array
		$sensor_type++;
		my @sensor_data = @{$_};

		for (my $value_type = 0; $value_type <2; $value_type++) {	#for oid type: name or value
			my $value_type_string;
			if ($value_type == 0) {	#text for extsnmp sub
				$value_type_string = "string";	#name oid
			} else {
				$value_type_string = "integer";	#value oid
			} # end if
			my $sensor_index;

			foreach (@sensor_data) {	#for sensor data row: name, value
				$sensor_index++;
				my @sensor_data_row = @{$_};				
				my $value = @sensor_data_row[$value_type];
				my $oid = "$base.$sensor_type.$value_type.$sensor_index";
				$extsnmp->add_oid_entry($oid, $value_type_string, $value);		
			}	
		}
	}


}
