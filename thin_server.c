#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <unistd.h>
#include "cercs_env.h"
#include "evpath.h"
#include "cm_internal.h"

static void socket_accept_thin_client(void *cmv, void * sockv);
extern void CMget_qual_hostname(char *buf, int len);

#ifndef SOCKET_ERROR
#define SOCKET_ERROR -1
#endif

extern int
EVthin_socket_listen(CManager cm,  char **hostname_p, int *port_p)
{

    unsigned int length;
    struct sockaddr_in sock_addr;
    int sock_opt_val = 1;
    int conn_sock;
    int int_port_num = 0;
    u_short port_num = 0;
    char host_name[256];

    conn_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (conn_sock == SOCKET_ERROR) {
	fprintf(stderr, "Cannot open INET socket\n");
	return 0;
    }
    sock_addr.sin_family = AF_INET;
    sock_addr.sin_addr.s_addr = INADDR_ANY;
    sock_addr.sin_port = htons(port_num);
    if (setsockopt(conn_sock, SOL_SOCKET, SO_REUSEADDR, (char *) &sock_opt_val,
		   sizeof(sock_opt_val)) != 0) {
	fprintf(stderr, "Failed to set 1REUSEADDR on INET socket\n");
	return 0;
    }
    if (bind(conn_sock, (struct sockaddr *) &sock_addr,
	     sizeof sock_addr) == SOCKET_ERROR) {
	fprintf(stderr, "Cannot bind INET socket\n");
	return 0;
    }
    sock_opt_val = 1;
    if (setsockopt(conn_sock, SOL_SOCKET, SO_REUSEADDR, (char *) &sock_opt_val,
		   sizeof(sock_opt_val)) != 0) {
	perror("Failed to set 2REUSEADDR on INET socket");
	return 0;
    }
    length = sizeof sock_addr;
    if (getsockname(conn_sock, (struct sockaddr *) &sock_addr, &length) < 0) {
	fprintf(stderr, "Cannot get socket name\n");
	return 0;
    }
    /* begin listening for conns and set the backlog */
    if (listen(conn_sock, FD_SETSIZE)) {
	fprintf(stderr, "listen failed\n");
	return 0;
    }
    /* set the port num as one we can be contacted at */
    
    CM_fd_add_select(cm, conn_sock, socket_accept_thin_client,
		    (void *) cm, (void *) (long)conn_sock);
    

    int_port_num = ntohs(sock_addr.sin_port);

    CMget_qual_hostname(host_name, sizeof(host_name));
	
    *hostname_p = strdup(host_name);
    *port_p = int_port_num;
    return 1;
}


typedef struct thin_conn {
    FFSFile ffsfile;
    int fd;
    int target_stone;
    int format_count;
    FMStructDescList *format_list;
    int max_src_list;
    EVsource *src_list;
} *thin_conn_data;

static void thin_free_func(void *event_data, void *client_data)
{
    free(event_data);
}

static void
thin_data_available(void *cmv, void * conn_datav)
{
    thin_conn_data cd = conn_datav;
    CManager cm = (CManager) cmv;
    int i;

    switch(FFSnext_record_type(cd->ffsfile)) {
    case FFSindex:
	break;
    case FFSend:
    case FFSerror:
	close_FFSfile(cd->ffsfile);
	free_FFSfile(cd->ffsfile);
	for (i=0; i < cd->format_count; i++) {
	    int j = 0;
	    while((cd->format_list[i])[j].format_name != NULL) {
		int k = 0;
		free(cd->format_list[i][j].format_name);
		while (cd->format_list[i][j].field_list[k].field_name != NULL) {
		    free((char*)cd->format_list[i][j].field_list[k].field_name);
		    free((char*)cd->format_list[i][j].field_list[k].field_type);
		    k++;
		}
		j++;
	    }
	}
	free(cd->format_list);
	for (i=0; i <= cd->max_src_list; i++) {
	    if (cd->src_list[i] != NULL) {
		EVfree_source(cd->src_list[i]);
	    }
	}
	free(cd->src_list);
	CM_fd_remove_select(cm, cd->fd);
	free(cd);
	break;
    case FFSformat: {
	FFSTypeHandle next_format = FFSread_format(cd->ffsfile);
	FMStructDescList formats = 
	    get_localized_formats(FMFormat_of_original(next_format));
	FFSTypeHandle target = 
	    FFSset_fixed_target(FFSContext_of_file(cd->ffsfile), 
				formats);
	int format_num = FMformat_index(FMFormat_of_original(target));
	if (cd->format_list == NULL) {
	    cd->format_list = malloc(sizeof(cd->format_list[0]));
	    cd->format_count = 1;
	}
	if (cd->format_count < format_num) {
	    cd->format_list = 
		realloc(cd->format_list, 
			(format_num + 1) * sizeof(cd->format_list[0]));
	    memset(cd->format_list + cd->format_count, 0,
		   sizeof(cd->format_list[0]) * (format_num -cd->format_count ));
	    cd->format_count = format_num + 1;
	}
	cd->format_list[format_num] = formats;
	break;
    }
    case FFSdata: {
	FFSTypeHandle next_format = FFSnext_type_handle(cd->ffsfile);
	int len = FFSnext_data_length(cd->ffsfile);
	int format_num = FMformat_index(FMFormat_of_original(next_format));
	void *data = malloc(len);
	FFSread(cd->ffsfile, data);
	if (cd->max_src_list < format_num) {
	    cd->src_list = realloc(cd->src_list, 
				   (format_num+1) * sizeof(cd->src_list[0]));
	    memset(&cd->src_list[cd->max_src_list], 0,
		   (format_num - cd->max_src_list) * sizeof(cd->src_list[0]));
	    cd->max_src_list = format_num;
	}
	if (cd->src_list[format_num] == NULL) {
	    cd->src_list[format_num] = 
		EVcreate_submit_handle_free(cm, cd->target_stone, 
					    cd->format_list[format_num],
					    thin_free_func, cd);
	}
	EVsubmit(cd->src_list[format_num], data, NULL);
	break;
    }
    case FFScomment: {
	char *comment = FFSread_comment(cd->ffsfile);
	if (strncmp(comment, "Stone ", 6) == 0) {
	    int tmp_stone;
	    if (sscanf(comment, "Stone %d", &tmp_stone) == 1) {
		cd->target_stone = tmp_stone;
	    }
	}
	break;
    }
    }
}

static void
socket_accept_thin_client(void *cmv, void * sockv)
{
    CManager cm = (CManager) cmv;
    int conn_sock = (int) (long)sockv;
    int sock;
    struct sockaddr sock_addr;
    unsigned int sock_len = sizeof(sock_addr);
    int int_port_num;
    struct linger linger_val;
    int sock_opt_val = 1;
    thin_conn_data cd;

#ifdef TCP_NODELAY
    int delay_value = 1;
#endif

    linger_val.l_onoff = 1;
    linger_val.l_linger = 60;
    if ((sock = accept(conn_sock, (struct sockaddr *) 0, (unsigned int *) 0)) == SOCKET_ERROR) {
	perror("Cannot accept socket connection");
	CM_fd_remove_select(cm, conn_sock);
	fprintf(stderr, "failure in CMsockets  removing socket connection\n");
	return;
    }
    sock_opt_val = 1;
    setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, (char *) &sock_opt_val,
	       sizeof(sock_opt_val));
    if (setsockopt(sock, SOL_SOCKET, SO_LINGER, (char *) &linger_val,
		   sizeof(struct linger)) != 0) {
	perror("set SO_LINGER");
	return;
    }
#ifdef TCP_NODELAY
    setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, (char *) &delay_value,
	       sizeof(delay_value));
#endif

    sock_len = sizeof(sock_addr);
    memset(&sock_addr, 0, sock_len);
    getsockname(sock, (struct sockaddr *) &sock_addr, &sock_len);
    int_port_num = ntohs(((struct sockaddr_in *) &sock_addr)->sin_port);

    memset(&sock_addr, 0, sizeof(sock_addr));
    sock_len = sizeof(sock_addr);
    if (getpeername(sock, &sock_addr,
		    &sock_len) == 0) {
	int_port_num = ntohs(((struct sockaddr_in *) &sock_addr)->sin_port);
    }

    cd = malloc(sizeof(*cd));
    memset(cd, 0, sizeof(*cd));
    cd->ffsfile = open_FFSfd((void*)(long)sock, "r");
    cd->fd = sock;
    cd->src_list = malloc(sizeof(cd->src_list[0]));
    cd->src_list[0] = NULL;
    CM_fd_add_select(cm, sock,
		     (void (*)(void *, void *)) thin_data_available,
		       (void *) cm, (void *) cd);
}
