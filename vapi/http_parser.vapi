/*
 * This file is part of the webcon project.
 * 
 * Copyright 2013 Richard Wiedenhöft <richard.wiedenhoeft@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

[CCode(cheader_filename="http_parser.h", cprefix="", lower_case_cprefix="")]
namespace Native.HttpParser {
	[CCode(cname="http_parser")]
	public struct http_parser {
		public short http_major;
		public short http_minor;
		public short status_code;
		public char method;
		public char http_errno;
		public char upgrade;
		public void *data;
	}

	[CCode(cname="http_parser_settings")]
	public struct http_parser_settings {
		public void *on_message_begin;
		public void *on_url;
		public void *on_status_complete;
		public void *on_header_field;
		public void *on_header_value;
		public void *on_headers_complete;
		public void *on_body;
		public void *on_message_complete;
	}	

	[CCode(cname="http_parser_type",cprefix="")]
	public enum http_parser_type {
		HTTP_REQUEST,
		HTTP_RESPONSE,
		HTTP_BOTH
	}
	
	[CCode(cname="http_parser_init")]
	public void http_parser_init(http_parser *parser, http_parser_type type);

	[CCode(cname="http_parser_execute")]
	size_t http_parser_execute(http_parser *parser, http_parser_settings *settings, char *data, size_t len);

	[CCode(cname="http_errno_name")]
	string http_errno_name(int errno);

	[CCode(cname="http_errno_description")]
	string http_errno_description(int errno);
}
