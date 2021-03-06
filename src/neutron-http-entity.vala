/*
 * This file is part of the neutron project.
 * 
 * Copyright 2013 Richard Wiedenhöft <richard.wiedenhoeft@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Represents the response to a certain request.
 *
 * Responsible for responding to all http-requests. Implements
 * the whole low-level functionality required to answer to requests
 * such a gzip-compression or chunk-encoding.
 */
 public abstract class Neutron.Http.Entity : Object {
	private ZlibCompressor gzip_converter;
	private ConverterOutputStream gzip_stream;

	private ChunkConverter chunk_converter;
	private ConverterOutputStream chunk_stream;

	private Server server;

	/**
	 * Always write to this stream. It applies chunk-encoding and/or gzip-compression where necessary
	 */
	private OutputStream outstream;
	
	/**
	 * Direct connection to the client.
	 *
	 * May be useful for protocol-upgrades
	 */
	protected IOStream io_stream {
		get;
		private set;
	}

	protected bool status_sent {
		get;
		private set;
		default = false;
	}

	protected bool headers_sent {
		get;
		private set;
		default = false;
	}

	protected Request request {
		get;
		private set;
	}

	private TransferEncoding _transfer_encoding = TransferEncoding.CHUNKED;
	protected TransferEncoding transfer_encoding {
		get { return _transfer_encoding; }
		set {
			if(!status_sent) _transfer_encoding = value;
			else assert_not_reached();
		}
	}

	private ContentEncoding _content_encoding = ContentEncoding.NONE;
	protected ContentEncoding content_encoding {
		get { return _content_encoding; }
		set {
			if(!headers_sent) _content_encoding = value;
			else assert_not_reached();
		}
	}

	/**
	 * Called by the server. Initializes this class somewhat
	 */
	public async ConnectionAction server_callback(Server server, Request request, IOStream io_stream) {
		this.request = request;
		this.io_stream = io_stream;
		this.outstream = io_stream.output_stream;
		this.server = server;

		var accepted_encodings = request.get_header_var("accept-encoding");
		if(accepted_encodings != null) {
			var enc_array = accepted_encodings.split(",");
			foreach(string enc in enc_array) {
				if(enc.strip().down() == "gzip") {
					content_encoding = ContentEncoding.GZIP;
					break;
				}
			}
		}

		return yield handle_request();
	}

	/**
	 * This just sends something to the client.
	 *
	 * Needed because send and send_bytes throw errors when called
	 * before headers are sent.
	 */
	private async void real_send(uint8[] data) throws Error {
		yield outstream.write_async(data);
	}

	/**
	 * Send the contents of data to the client
	 */
	protected async void send_bytes(uint8[] data) throws Error {
		if(!headers_sent) throw new HttpError.HEADERS_NOT_SENT("You have to call end_headers() before calling send() or send_bytes()");
		else yield real_send(data);
	}

	/**
	 * Convenience-wrapper for send_bytes
	 */
	protected async void send(string str) throws Error {
		var data = (uint8[]) str.to_utf8();
		yield send_bytes(data);
	}

	/**
	 * Call this after you sent the whole entity
	 *
	 * This is absolutely necessary when using Transfer- or ContentEncoding,
	 * because the browser will fail if you do not call it then.
	 */
	protected async void end_body() throws Error {
		if(_content_encoding == ContentEncoding.GZIP) yield gzip_stream.close_async();
		if(_transfer_encoding == TransferEncoding.CHUNKED) yield chunk_stream.close_async();
	}

	/**
	 * Sends HTTP-Status
	 */
	protected async void send_status(int code, string? description = null) throws Error {
		if(status_sent) throw new HttpError.STATUS_ALREADY_SENT("You can not send the status twice");

		string desc = "";
		/* Just a few common codes. Contribute more if you like */
		switch(code) {
		case 100:
			desc = "Continue";
			break;
		case 101:
			desc = "Switching Protocols";
			break;
		case 102:
			desc = "Processing";
			break;
		case 200:
			desc = "OK";
			break;
		case 301:
			desc = "Moved Permanently";
			break;
		case 302:
			desc = "Found";
			break;
		case 400:
			desc = "Bad Request";
			break;
		case 401:
			desc = "Unauthorized";
			break;
		case 403:
			desc = "Forbidden";
			break;
		case 404:
			desc = "Not Found";
			break;
		case 426:
			desc = "Upgrade Required";
			break;
		case 500:
			desc = "Internal Server Error";
			break;
		}

		if(description != null) desc = description;
		yield real_send((uint8[]) "HTTP/1.1 %d %s\r\n".printf(code, desc).to_utf8());
		status_sent = true;
		yield send_default_headers();
	}

	/**
	 * Sends header-line to client
	 */
	protected async void send_header(string key, string val) throws Error {
		if(!status_sent) throw new HttpError.STATUS_NOT_SENT("You have to send the status first");
		if(headers_sent) throw new HttpError.HEADERS_ALREADY_SENT("Already in body of message");
		yield real_send((uint8[]) "%s: %s\r\n".printf(key, val).to_utf8());
	}

	/**
	 * Sends headers chosen by the library (Content-Encoding for example)
	 */
	protected virtual async void send_default_headers() throws Error {
		yield send_header("Server", "neutron");
		if(_transfer_encoding == TransferEncoding.CHUNKED) yield send_header("Transfer-Encoding", "chunked");
		if(_content_encoding == ContentEncoding.GZIP) yield send_header("Content-Encoding", "gzip");
	}

	/**
	 * Call this after you sent all headers.
	 *
	 * After calling this method you are able to use the send and send_bytes methods.
	 * It is also impossible to send headers after calling it.
	 */
	protected async void end_headers() throws Error {
		yield real_send((uint8[]) "\r\n".to_utf8());
		headers_sent = true;

		if(_transfer_encoding == TransferEncoding.CHUNKED) {
			chunk_converter = new ChunkConverter();
			chunk_stream = new ConverterOutputStream(outstream, chunk_converter);
			chunk_stream.set_close_base_stream(false);
			outstream = chunk_stream;
		}

		if(_content_encoding == ContentEncoding.GZIP) {
			gzip_converter = new ZlibCompressor(ZlibCompressorFormat.GZIP);
			gzip_stream = new ConverterOutputStream(outstream, gzip_converter);
			gzip_stream.set_close_base_stream(false);
			outstream = gzip_stream;
		}
	}


	/**
	 * Convenience-wrapper for send_header-method. Sets a cookie.
	 */
	protected async void set_cookie(string key,
					string val,
					int lifetime,
					string path = "/",
					bool http_only = false,
					bool secure = false) throws Error {

		var cookie = new StringBuilder();

		cookie.append("%s=%s".printf(key, val));
		cookie.append("; Max-Age=%d".printf(lifetime));
		cookie.append("; Path=%s".printf(path));

		if(http_only) cookie.append("; HttpOnly");
		if(secure) cookie.append("; Secure");

		yield send_header("Set-Cookie", cookie.str);
	}

	/**
	 * Sets a session within the server
	 */
	protected async void set_session(Session? session) throws Error {
		if(session != null) {
			yield set_cookie("neutron_session_id", session.session_id, 24*3600, "/");
			if(request.session != null && request.session.session_id != session.session_id) {
				Session.delete_by_id(request.session.session_id);
			}
		} else {
			yield set_cookie("neutron_session_id", "deleted", -1);
			if(request.session != null) {
				Session.delete_by_id(request.session.session_id);
			}
		}
	}

	/**
	 * Override this method to write you own entity.
	 */
	protected abstract async ConnectionAction handle_request();
}

public enum Neutron.Http.TransferEncoding {
	NONE,
	CHUNKED
}

public enum Neutron.Http.ContentEncoding {
	NONE,
	GZIP
}

