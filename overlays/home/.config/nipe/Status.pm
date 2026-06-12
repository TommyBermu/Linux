package Nipe::Utils::Status;
use JSON;
use strict;
use warnings;

sub new {
    my $apiCheck = "https://check.torproject.org/api/ip";
    my $content = `curl -s --socks5-hostname 127.0.0.1:9050 $apiCheck`;

    if ($content) {
        my $data = decode_json($content);
        my $checkIp  = $data->{'IP'};
        my $checkTor = $data->{'IsTor'} ? "activated" : "disabled";
        return "\n\r[+] Status: $checkTor. \n\r[+] Ip: $checkIp\n\n";
    }
    return "\n[!] ERROR: sorry, it was not possible to establish a connection to the server.\n\n";
}
1; 
