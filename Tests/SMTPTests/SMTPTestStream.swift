import Core
import Transport
@testable import SMTP

let username = "user"
let password = "****"
let baduser = "bad-user"
let badpass = "bad-pass"

let plainLogin = "\0\(username)\0\(password)".makeBytes().base64Encoded.string

let greeting = "220 smtp.gmail.com at your service"
let ehloResponse = "250-smtp.sendgrid.net\r\n250-8BITMIME\r\n250-SIZE 31457280\r\n250-AUTH PLAIN LOGIN\r\n250 AUTH=PLAIN LOGIN"

private let SMTPReplies: [String: String] = [
    "AUTH LOGIN\r\n": "334 " + "Username:".makeBytes().base64Encoded.string,
    username.makeBytes().base64Encoded.string + "\r\n": "334 " + "Password:".makeBytes().base64Encoded.string,
    password.makeBytes().base64Encoded.string + "\r\n": "235 passed",
    baduser.makeBytes().base64Encoded.string + "\r\n": "500 invalid username",
    badpass.makeBytes().base64Encoded.string + "\r\n": "500 invalid password",
    "AUTH PLAIN " + plainLogin + "\r\n": "235 passed",
    "TEST LINE" + "\r\n": "042 ok",
    "EHLO localhost" + "\r\n": ehloResponse,
    "QUIT" + "\r\n": "221 ok, buh bye",
    "MAIL FROM: <from@email.com>" + "\r\n": "250 go on",
    "RCPT TO: <to1@email.com>" + "\r\n": "250 go on",
    "RCPT TO: <to2@email.com>" + "\r\n": "250 go on",
    "DATA" + "\r\n": "354 data ok",
    "\r\n.\r\n": "250 email done"
]

final class SMTPTestStream: Transport.ClientStream, Transport.Stream {

    public var peerAddress: String {
        return "\(host):\(port)"
    }

    var closed: Bool
    var buffer: Bytes

    let host: String
    let port: Int
    let securityLayer: SecurityLayer

    init(host: String, port: Int, securityLayer: SecurityLayer) {
        closed = false
        buffer = []

        self.host = host
        self.port = port
        self.securityLayer = securityLayer
    }

    func setTimeout(_ timeout: Double) throws {

    }

    func close() throws {
        if !closed {
            closed = true
        }
    }

    func send(_ bytes: Bytes) throws {
        closed = false
        if let response = SMTPReplies[bytes.string] {
            if bytes.string == "\r\n.\r\n" {
                // email data terminator. overwrite buffer of dummy email
                buffer = response.makeBytes()
            } else {
                buffer += response.makeBytes()
            }
        } else {
            // If reply not known, set to buffer
            buffer += bytes
        }
    }

    func flush() throws {

    }

    func receive(max: Int) throws -> Bytes {
        if buffer.count == 0 {
            try close()
            return []
        }

        if max >= buffer.count {
            try close()
            let data = buffer
            buffer = []
            return data
        }

        let data = buffer[0..<max]
        buffer.removeFirst(max)

        return Bytes(data)
    }
    
    func connect() throws -> Transport.Stream {
        return self
    }
}
