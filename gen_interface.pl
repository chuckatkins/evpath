#! /usr/bin/env - perl

sub gen_type
{
    my($subr, $arg_str) = @_;
    my(@args);
    print REVP "\ntypedef struct _${subr}_request {\n";
    print REVP "    int condition_var;\n";
    @args = split( ", ",  $arg_str,2);
    foreach $arg (split (", ", $args[1])) {
	$_ = $arg;
	if (/^\s*(.*\W+)(\w+)$\s*/) {
	    $argtype = $1;
	    $argname = $2;
	    $argtype =~ s/\s+$//;
	    $argtype =~ s/(?!\w)\s+(?=\W)//;  #remove unnecessary white space
	    $argtype =~ s/(?!\W)\s+(?=\w)//;  #remove unnecessary white space
	    $iotype = $argtype;
	    $sizetype = $argtype;
	  switch:for ($argtype) {
	      /attr_list/ && do {$iotype = "string"; $argtype="char*"; last;};
	      /char*/ && do {$iotype = "string"; $argtype="char*"; last;};
	      /EVstone$/ && do {$iotype = "integer"; $argtype="EVstone"; last;};
	      /EVstone\*/ && do {print REVP "    int ${argname}_len;\n";
$iotype = "integer[${argname}_len]"; $argtype="int *"; last;};
	      /EVSimpleHandlerFunc$/ && do {$iotype = "string"; $argtype="char*"; last;};
	      /FMStructDescList/ && do {$iotype = "string"; $argtype="char*"; last;};
	  }
	}
	print REVP "    $argtype $argname;\n";
    }
    print REVP "} ${subr}_request;\n";
    $ret_type = $return_type{$subr};
  switch:  for ($ret_type) {
      /attr_list/ && do {$retiotype = "string"; $ret_type="char*"; last;};
      /char*/ && do {$retiotype = "string"; $ret_type="char*"; last;};
      /EVstone/ && do {$retiotype = "integer"; $ret_type="EVstone"; last;};
    }
    print REVP "\ntypedef struct _${subr}_response {\n";
    print REVP "    int condition_var;\n";
    print REVP "    $ret_type ret;\n" unless ($return_type{$subr} eq "void");
    print REVP "} ${subr}_response;\n";
}

sub gen_field_list
{
    my($subr, $arg_str) = @_;
    my(@args);
    print REVP "\nFMField  ${subr}_req_flds[] = {\n";
    print REVP "    {\"condition_var\", \"integer\", sizeof(int), FMOffset(${subr}_request*, condition_var)},\n";
    @args = split( ", ",  $arg_str,2);
    foreach $arg (split (", ", $args[1])) {
	$_ = $arg;
	if (/^\s*(.*\W+)(\w+)$\s*/) {
	    $argtype = $1;
	    $argname = $2;
	    $argtype =~ s/\s+$//;
	    $argtype =~ s/(?!\w)\s+(?=\W)//;  #remove unnecessary white space
	    $argtype =~ s/(?!\W)\s+(?=\w)//;  #remove unnecessary white space
	    $iotype = $argtype;
	    $sizetype = $argtype;
	  switch:for ($argtype) {
	      /attr_list/ && do {$iotype = "string"; $argtype="char*"; last;};
	      /char*/ && do {$iotype = "string"; $argtype="char*"; last;};
	      /int/ && do {$iotype = "integer"; $argtype="int"; last;};
	      /EVstone/ && do {$iotype = "integer"; $argtype="EVstone"; last;};
	      /EVaction/ && do {$iotype = "integer"; $argtype="EVaction"; last;};
	      /EVSimpleHandlerFunc/ && do {$iotype = "string"; $argtype="EVSimpleHandlerFunc"; last;};
	      /FMStructDescList/ && do {$iotype = "string"; $argtype="EVSimpleHandlerFunc"; last;};
	  }
	}
	print REVP "    {\"$argname\", \"$iotype\", sizeof($sizetype), FMOffset(${subr}_request*,$argname)},\n";
    }
    print REVP "    {NULL, NULL, 0, 0}\n};\n";
    print REVP "\nFMStructDescRec  ${subr}_req_formats[] = {\n";
    print REVP "    {\"EV_${subr}_request\", ${subr}_req_flds, sizeof(${subr}_request), NULL},\n";
    print REVP "    {NULL, NULL, 0, NULL}\n};\n";
}

sub gen_stub {
    my($subr, $arg_str) = @_;
    my(@args);
    @args = split( ", ",  $arg_str,2);
    print REVP "\nextern $return_type{$subr}\n";
    if ($#args > 0) {
	print REVP "R$subr(CMConnection conn, $args[1])\n";
    } else {
	print REVP "R$subr(CMConnection conn)\n";
    }
    print REVP "{\n";
    
    $_ = $return_type{$subr};
    if (/^\s*void\s*$/) {
	$return_type{$subr} = "void";
    }
    $retsubtype = $return_type{$subr};
  switch:  for ($ret_type) {
      /attr_list/ && do {$retsubtype = "string"; $ret_type="char*"; last;};
      /char*/ && do {$retsubtype = "string"; $ret_type="char*"; last;};
      /EVstone/ && do {$retsubtype = "int"; $ret_type="EVstone"; last;};
      /EVaction/ && do {$retsubtype = "int"; $ret_type="EVaction"; last;};
    }
    print REVP "    int cond = CMCondition_get(conn->cm, conn);\n";
    print REVP "    CMFormat f = CMlookup_format(conn->cm, ${subr}_req_formats);\n";
    print REVP "    EV_${retsubtype}_response *response;\n" unless ($return_type{$subr} eq "void");
    print REVP "    ${subr}_request request;\n";
    foreach $arg (split (", ", $args[1])) {
	$_ = $arg;
	if (/^\s*(.*\W+)(\w+)$\s*/) {
	    $argtype = $1;
	    $argname = $2;
	    $argtype =~ s/\s+$//;
	    $argtype =~ s/(?!\w)\s+(?=\W)//;  #remove unnecessary white space
	    $argtype =~ s/(?!\W)\s+(?=\w)//;  #remove unnecessary white space
	    $argright = $argname;
	  switch:for ($argtype) {
	      /attr_list/ && do {$argright = "attr_list_to_string($argname)"; last;};
	      /FMStructDescList/ && do {$argright = "get_format_name(conn->cm, $argname)"; last;};
	  }
	}
	print REVP "    request.$argname = $argright;\n";
    }
    print REVP "    request.condition_var = cond;\n";
    print REVP "    if (f == NULL) {\n";
    print REVP "        f = CMregister_format(conn->cm, ${subr}_req_formats);\n";
    print REVP "    }\n";
    if ($return_type{$subr} eq "void") {
	print REVP "    CMCondition_set_client_data(conn->cm, cond, NULL);\n";
    } else {
	print REVP "    CMCondition_set_client_data(conn->cm, cond, &response);\n";
    }
    print REVP "    CMwrite(conn, f, &request);\n";
    print REVP "    CMCondition_wait(conn->cm, cond);\n";
  switch:for ($return_type{$subr}) {
      /attr_list/ && do {print REVP "    return attr_list_from_string(response->ret);\n"; last;};
      /void/ && do {last;};
      /EVstone/ && do {print REVP "    return (EVstone) response->ret;\n"; last;};
      /EVaction/ && do {print REVP "    return (EVaction) response->ret;\n"; last;};
      /int/ && do {print REVP "    return response->ret;\n"; last;};
      /EVevent_list/ && do {print REVP "    return response->ret;\n"; last;};
  }
    print REVP "}\n";
}

sub gen_handler {
    my($subr, $arg_str, $has_client_data) = @_;
    my(@args);
    @args = split( ", ",  $arg_str,2);
    print REVP "\nstatic void\n";
    print REVP "R${subr}_handler(CManager cm, CMConnection conn, void *data,void *client_data,attr_list attrs)\n";
    $handler_register_string = "$handler_register_string\
    tmp_format = CMregister_format(cm, ${subr}_req_formats);\
    CMregister_handler(tmp_format, R${subr}_handler, cm->evp);\n";

    print REVP "{\n";
    $_ = $return_type{$subr};
    if (/^\s*void\s*$/) {
	$return_type{$subr} = "void";
    }
    $retsubtype = $return_type{$subr};
  switch:  for ($ret_type) {
      /attr_list/ && do {$retsubtype = "string"; $ret_type="char*"; last;};
      /char*/ && do {$retsubtype = "string"; $ret_type="char*"; last;};
      /EVstone/ && do {$retsubtype = "int"; $ret_type="EVstone"; last;};
      /EVaction/ && do {$retsubtype = "int"; $ret_type="EVaction"; last;};
    }
    print REVP "    EV_${retsubtype}_response response;\n";
    print REVP "    ${subr}_request *request = (${subr}_request *) data;\n";
    print REVP "    $return_type{$subr} ret;\n" unless ($return_type{$subr} eq "void");
    print REVP "    CMFormat f = CMlookup_format(conn->cm, EV_${retsubtype}_response_formats);\n";
    print REVP "    if (f == NULL) {\n";
    print REVP "        f = CMregister_format(conn->cm, EV_${retsubtype}_response_formats);\n";
    print REVP "    }\n";
    foreach $arg (split (", ", $args[1])) {
	$_ = $arg;
	if (/^\s*(.*\W+)(\w+)$\s*/) {
	    $argtype = $1;
	    $argname = $2;
	    $argtype =~ s/\s+$//;
	    $argtype =~ s/(?!\w)\s+(?=\W)//;  #remove unnecessary white space
	    $argtype =~ s/(?!\W)\s+(?=\w)//;  #remove unnecessary white space
	    $argright = $argname;
	  switch:for ($argtype) {
	      /attr_list/ && do {print REVP "    attr_list $argname = attr_list_from_string(request->$argname);\n"; last;};
	      /EVSimpleHandlerFunc/ && do {print REVP "    EVSimpleHandlerFunc $argname = lookup_handler(request->$argname);\n"; last;};
	      /FMStructDescList/ && do {print REVP "    FMStructDescList $argname = lookup_format_structs(conn->cm, request->$argname);\n"; last;};
	  }
	}
    }
    if ($return_type{$subr} eq "void") {
	print REVP "    $subr(cm";
    } else {
	print REVP "    ret = $subr(cm";
    }
    foreach $arg (split (", ", $args[1])) {
	$_ = $arg;
	if (/^\s*(.*\W+)(\w+)$\s*/) {
	    $argtype = $1;
	    $argname = $2;
	    $argtype =~ s/\s+$//;
	    $argtype =~ s/(?!\w)\s+(?=\W)//;  #remove unnecessary white space
	    $argtype =~ s/(?!\W)\s+(?=\w)//;  #remove unnecessary white space
	    $argright = "request->$argname";
	  switch:for ($argtype) {
	      /attr_list/ && do {$argright = "$argname"; last;};
	      /EVSimpleHandlerFunc/ && do {$argright = "$argname"; last;};
	      /FMStructDescList/ && do {$argright = "$argname"; last;};
	  }
	}
	print REVP ", $argright";
    }
    if ($has_client_data == 1) {print REVP ", NULL";}
    print REVP ");\n";
  switch:for ($return_type{$subr}) {
      /attr_list/ && do {print REVP "    response.ret = attr_list_to_string(ret);\n"; last;};
      /void/ && do {last;};
      /EVstone/ && do {print REVP "    response.ret = (int)ret;\n"; last;};
      /EVaction/ && do {print REVP "    response.ret = (int) ret;\n"; last;};
      /int/ && do {print REVP "    response.ret = ret;;\n"; last;};
      /EVevent_list/ && do {print REVP "    response.ret = ret;\n"; last;};
  }
    print REVP "    response.condition_var = request->condition_var;\n";
    print REVP "    CMwrite(conn, f, &response);\n";
    print REVP "}\n";
}

sub strip_client_data {
    my($arg_str) = @_;
    local(@args);
    @args = split( ", ",  $arguments{$subr});
    $_ = pop(@args);
    if (!/.*client_data\W*$/) {
	push(@args, $_);
    }
    $arg_str = join(", ", @args);
}

sub mod_EVhandler {
    my($arg_str) = @_;
    local(@args);
    @args = split( ", ",  $arg_str);
    for( my $i=0; $i < scalar(@args); $i++) {
	$_ = $args[$i];
	if (/\W*EVSimpleHandlerFunc.*$/) {
	    $args[$i] = "char *handler";
	}
    }
    $arg_str = join(", ", @args);
    return $arg_str;
}

{
    local ($/, *INPUT);
	
    unless (open(INPUT,"<evpath.h")) {
	die "sudden flaming death, no evpath.h\n";
    }

    $_ = <INPUT>;
    s[/\*NOLOCK\*/][NOLOCK]g;
    s[/\*REMOTE\*/][REMOTE]g;
    s{/\*.+\*/}{}g;
    @f = split(/\n/);
    close INPUT;
}
LINE:
for (@f) {
    if (/NOLOCK/) {
	$nolock = 1;
    }
    if (/REMOTE/) {
	$remote = 1;
    }
    if (/^extern/) {
	next LINE if (/\"C\"/);
	$decl = "";
	if ($nolock == 1) {$decl = "NOLOCK";}
	if ($remote == 1) {$decl = "REMOTE";}
	$nolock = 0;
	$remote = 0;
	$pending = 1;
    }
    if (($pending) && /;/) {
	$decl = $decl . " " . $_;
	push (@DECLS, $decl);
	$pending = 0;
    }
    if ($pending) {
	$decl = $decl . " " . $_;
    }
}
for (@DECLS) {
    $nolock = 0;
    $remote = 0;
    if (/NOLOCK/) {
	s/NOLOCK//g;
	$nolock = 1;
    }
    if (/REMOTE/) {
	s/REMOTE//g;
	$remote = 1;
    }
    if (/extern\W+(\w+\W+)(\w+).*\((.*)\)/) {
	$return = $1;
	$name = $2;
	$_ = $3;
	s/\)//g;
	s/\s+/ /g;
	$return =~ s/(?!\w)\s+(?=\W)//;  #remove unnecessary white space
	$return =~ s/(?!\W)\s+(?=\w)//;  #remove unnecessary white space
	$return =~ s/\s*$//;  #remove unnecessary white space
	$return =~ s/^\s*//;  #remove unnecessary white space
	$return_type{$name} = $return;
	$args = $_;
	$arguments{$name} = "$args";
    }
    if ($nolock == 1) {
	$nolocking{$name} = 1;
    }
    if ($remote == 1) {
	$remote_enabled{$name} = 1;
    }
}

open FIXUP, ">fixup.pl";
print FIXUP "#!/usr/bin/env perl -pi.bak\n";
unless (open (INT, ">cm_interface.c")) { die "Failed to open cm_interface.c";}
print INT<<EOF;
/*
 *  This file is automatically generated by gen_interface.pl from evpath.h.
 *
 *  DO NOT EDIT
 *
 */
#include "ffs.h"
#include "atl.h"
#include "evpath.h"
#include "cm_internal.h"
#ifdef	__cplusplus
extern "C" \{
#endif
EOF
    foreach $subr (keys %return_type) {
	print INT "\nextern $return_type{$subr}\n";
	print INT "$subr ( $arguments{$subr} )\n";
	print INT "{\n";
	undef $cmanager;
	undef $cmconnection;
	undef $evsource;
	undef $cmtaskhandle;
	undef $cmformat;
	foreach $arg (split ( ",", $arguments{$subr})) {
	    $_ = $arg;
	    if (/\W+(\w+)\W*$/) {
		$name = $1;
	    }
	    if (/CManager/) {
		$cmanager = $name;
	    }
	    if (/CMConnection/) {
		$cmconnection = $name;
	    }
	    if (/EVsource/) {
		$evsource = $name;
	    }
	    if (/CMTaskHandle/) {
		$cmtaskhandle = $name;
	    }
	    if ((/CMFormat/) && (!/CMFormatList/)){
		$cmformat = $name;
	    }
	}

	$_ = $return_type{$subr};
	if (/^\s*void\s*$/) {
	    $return_type{$subr} = "void";
	}
	if ($return_type{$subr} ne "void") {
	    print INT "\t$return_type{$subr} ret;\n";
	}
	if (!defined($nolocking{$subr})) {
	    if (defined($cmanager)) {
		print INT "\tCManager_lock($cmanager);\n";
	    } else {
		if (defined($cmconnection)) {
		    print INT "\tCManager cm = $cmconnection->cm;\n";
		} elsif (defined($evsource)) {
		    print INT "\tCManager cm = $evsource->cm;\n";
		} elsif (defined($cmtaskhandle)) {
		    print INT "\tCManager cm = $cmtaskhandle->cm;\n";
		} elsif (defined($cmformat)) {
		    print INT "\tCManager cm = $cmformat->cm;\n";
		} else {
#		    print INT "\tCManager cm = duh;\n";
		}
		print INT "\tCManager_lock(cm);\n";
	    }
	}
	if ($return_type{$subr} eq "void") {
	    print INT "\t";
	} else {
	    print INT "\tret = ";
	}

	print INT "INT_$subr(";
	$first = 1;
	foreach $arg (split ( ",", $arguments{$subr})) {
	    if ($first != 1) {
		print INT ", ";
	    } else {
		$first = 0;
	    }
	    $_ = $arg;
	    if (/\W+(\w+)\W*$/) {
		print INT "$1";
	    }
	}
	print INT ");\n";
	if ((!defined($nolocking{$subr})) && ($subr ne "CManager_close")) {
	    if (defined($cmanager)) {
		print INT "\tCManager_unlock($cmanager);\n";
	    } else {
		print INT "\tCManager_unlock(cm);\n";
	    }
	}
	print INT "\treturn ret;\n" unless ($return_type{$subr} eq "void");
	print INT "}\n";
	print FIXUP "s/$subr/INT_$subr/g unless /INT_$subr/;\n";
    }
print "done\n";

print INT<<EOF;
#ifdef	__cplusplus
\}
#endif
EOF
close INT;
unless (open (REVPH, ">revpath.h")) { die "Failed to open revpath.h";}
print REVPH<<EOF;
/*
 *  This file is automatically generated by gen_interface.pl from evpath.h.
 *
 *  DO NOT EDIT
 *
 */
EOF
unless (open (REVP, ">revp.c")) { die "Failed to open revp.c";}
print REVP<<EOF;
/*
 *  This file is automatically generated by gen_interface.pl from evpath.h.
 *
 *  DO NOT EDIT
 *
 */
#include "ffs.h"
#include "atl.h"
#include "evpath.h"
#include "cm_internal.h"
#include "libltdl/ltdl.h"
#include "stdio.h"
#ifdef	__cplusplus
extern "C" \{
#endif

typedef struct _EV_void_response {
    int condition_var;
} EV_void_response;

FMField  EV_void_response_flds[] = {
    {"condition_var", "integer", sizeof(int), FMOffset(EV_void_response*, condition_var)},
    {NULL, NULL, 0, 0}
};

FMStructDescRec  EV_void_response_formats[] = {
    {"EV_void_response", EV_void_response_flds, sizeof(EV_void_response), NULL},
    {NULL, NULL, 0, NULL}
};

typedef struct _EV_int_response {
    int condition_var;
    int  ret;
} EV_int_response;

FMField  EV_int_response_flds[] = {
    {"condition_var", "integer", sizeof(int), FMOffset(EV_int_response*, condition_var)},
    {"ret", "integer", sizeof(EVstone), FMOffset(EV_int_response*,ret)},
    {NULL, NULL, 0, 0}
};

FMStructDescRec  EV_int_response_formats[] = {
    {"EV_int_response", EV_int_response_flds, sizeof(EV_int_response), NULL},
    {NULL, NULL, 0, NULL}
};

typedef struct _EV_string_response {
    int condition_var;
    char *ret;
} EV_string_response;

FMField  EV_string_response_flds[] = {
    {"condition_var", "integer", sizeof(int), FMOffset(EV_string_response*, condition_var)},
    {"ret", "string", sizeof(char*), FMOffset(EV_string_response*,ret)},
    {NULL, NULL, 0, 0}
};

FMStructDescRec  EV_string_response_formats[] = {
    {"EV_string_response", EV_string_response_flds, sizeof(EV_string_response), NULL},
    {NULL, NULL, 0, NULL}
};

typedef struct _EV_EVevent_list_response {
    int condition_var;
    int ret_len;
    EVevent_list ret;
} EV_EVevent_list_response;

FMField  EV_EVevent_list_response_flds[] = {
    {"condition_var", "integer", sizeof(int), FMOffset(EV_EVevent_list_response*, condition_var)},
    {"ret_len", "integer", sizeof(int), FMOffset(EV_EVevent_list_response*,ret_len)},
    {"ret", "string", sizeof(char*), FMOffset(EV_EVevent_list_response*,ret)},
    {NULL, NULL, 0, 0}
};

FMStructDescRec  EV_EVevent_list_response_formats[] = {
    {"EV_EVevent_response", EV_EVevent_list_response_flds, sizeof(EV_EVevent_list_response), NULL},
    {NULL, NULL, 0, NULL}
};

static EVSimpleHandlerFunc
lookup_handler(char *name)
{
    static lt_dlhandle h = NULL;
    if (h == NULL) {
	lt_dlinit();
	lt_dlopen(NULL);
    }
    return lt_dlsym(h, name);
}

static char *
get_format_name(CManager cm, FMStructDescList structs)
{
    int id_len, i;
    FMFormat format = EVregister_format_set(cm, structs);
    char *tmp = get_server_ID_FMformat(format, &id_len);
    char *str_tmp = malloc(id_len * 2 + 1);
    for (i=0; i < id_len; i++) {
	sprintf(&str_tmp[i*2], "%02x", ((unsigned char*)tmp)[i]);
    }
    return str_tmp;
}

static FMStructDescList
lookup_format_structs(CManager cm, char *format_name)
{
    FMFormat format;
    int slen = strlen(format_name);
    int i;
    unsigned char *id = malloc(slen/2);
    for (i=0; i < slen/2; i++) {
	int x;
	char tmp[3] = {0, 0, 0};
	tmp[0] = format_name[2*i];
	tmp[1] = format_name[2*i + 1];
	sscanf(tmp, "%x", &x);
	id[i] = x;
    }
    format = FMformat_from_ID(cm->evp->fmc, id);
    free(id);
    return format_list_of_FMFormat(format);
}

EOF
    foreach $subr (keys %return_type) {
	defined($remote_enabled{$subr}) || next;

	print REVPH "\nextern $return_type{$subr}\n";
	$no_client_data = strip_client_data($arguments{$subr});
	$no_handler = mod_EVhandler($no_client_data);
	$_ = $arguments{$subr};
	$has_client_data = 0;
	if (/.*client_data\W*$/) {
	    $has_client_data = 1;
	}
	@args = split( ", ",  $no_handler, 2);
	if ($#args > 0) {
	    print REVPH "R$subr(CMConnection conn, $args[1]);\n";
	} else {
	    print REVPH "R$subr(CMConnection conn);\n";
	}
	gen_type(${subr}, $no_handler);
	gen_field_list(${subr}, $no_handler);
	gen_stub(${subr}, $no_handler);
	gen_handler(${subr}, $no_client_data, $has_client_data);
    }

print REVP<<EOF;
static void
REV_response_handler(CManager cm, CMConnection conn, void *data,void *client_data,attr_list attrs)
{
    EV_void_response *response = (EV_void_response*) data;
    CMtake_buffer(cm, data);
    void **response_ptr = CMCondition_get_client_data(cm, response->condition_var);
    if (NULL != response_ptr) {
	*response_ptr = data;
    }
    CMCondition_signal(cm, response->condition_var);
}


extern void
REVPinit(CManager cm)
{
    CMFormat tmp_format;
$handler_register_string
    tmp_format = CMregister_format(cm, EV_int_response_formats);
    CMregister_handler(tmp_format, REV_response_handler, cm->evp);

    tmp_format = CMregister_format(cm, EV_void_response_formats);
    CMregister_handler(tmp_format, REV_response_handler, cm->evp);

    tmp_format = CMregister_format(cm, EV_string_response_formats);
    CMregister_handler(tmp_format, REV_response_handler, cm->evp);

    tmp_format = CMregister_format(cm, EV_EVevent_list_response_formats);
    CMregister_handler(tmp_format, REV_response_handler, cm->evp);
}
EOF
