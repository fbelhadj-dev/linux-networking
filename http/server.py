#!/usr/bin/python

import socket
from contextlib import contextmanager
from typing import Generator

ADDRESS = "0.0.0.0"
PORT = 8000
BUFFER_SIZE = 2048


@contextmanager
def prepare_socket() -> Generator[socket.socket, None, None]:
    """
    Prepare TCP socket to transport http data
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) # allow immediate re-use of PORT at restart
    sock.bind((ADDRESS, PORT))
    sock.listen()

    try:
        yield sock
    except KeyboardInterrupt:
        sock.close()


def collect_http_data(conn: socket.socket) -> bytes:
    """
    Read http data from connection until connection close is raised by \r\n\r\n sequence
    """
    collected_data = b''

    while True:
        data = conn.recv(BUFFER_SIZE)
        collected_data += data

        if b"\r\n\r\n" in data or not data:
            return collected_data


def send_http_response(conn: socket.socket, addr: str) -> None:
    header = (
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: text/plain\r\n"
        "Content-Length: {}\r\n"
        "Connection: close\r\n\r\n"
    )
    msg = f"Hello {addr} !"

    conn.sendall((header.format(len(msg)) + msg).encode("utf-8"))


if __name__ == '__main__':
    with prepare_socket() as sock:
        while True:
            conn, addr = sock.accept()
            
            with conn:
                print(collect_http_data(conn))
                send_http_response(conn, addr)