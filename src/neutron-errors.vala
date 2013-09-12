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

namespace Neutron {
	public errordomain ConfigurationError {
		REQUIRED_OPTION_MISSING,
		INVALID_OPTION
	}

	namespace Http {
		public errordomain HttpError {
			STATUS_ALREADY_SENT,
			STATUS_NOT_SENT,
			HEADERS_ALREADY_SENT,
			HEADERS_NOT_SENT
		}
	}

	namespace Websocket {
		public errordomain WebsocketError {
			CONNECTION_CLOSED_UNEXPECTEDLY,
			MAX_FRAME_SIZE_EXCEEDED
		}
	}
}
