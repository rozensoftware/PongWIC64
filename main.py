import socket
import time
import keyboard
import threading
import socketserver
import pong
from player import Player
import select

MAX_DATA_RECEIVE = 256  # Maximum data size to receive from the socket
PADDLE_MOVE_SPEED = 4  # Speed of paddle movement
C64_BORDER_WIDTH = 24  # Width of the border in pixels
C64_BORDER_HEIGHT = 50  # Height of the border in pixels
DEBUG = 0 # Set to 1 for debug mode, 0 for production
PORT = 6502  # Default port for the TCP server

player_map = {}
player_map_lock = threading.Lock()  # Added lock for thread-safe access to player_map

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # doesn't even have to be reachable
        s.connect(('10.254.254.254', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

class TCPRequestHandler(socketserver.BaseRequestHandler):
    def __init__(self, *args, stop_event=None, **kwargs):
        self.stop_event = stop_event  # Store the stop_event
        super().__init__(*args, **kwargs)

    def remove_client(self):
        with player_map_lock:
            for player, (ip, port) in list(player_map.items()):
                if player.get_socket() == self.request:
                    try:
                        if self.request:
                            self.request.close()
                            self.request = None
                    except Exception as e:
                        print(f"Error while closing socket for player {player}: {e}")
                    finally:
                        del player_map[player]
                        print(f"Player {player} removed from the game.")
                    break
            
    def handle(self):
        try:
            # Set a timeout for reading data from the client
            self.request.settimeout(50.0)  # Timeout set to 5 seconds

            # Log the connection moment and client's IP address
            print(f"New connection from {self.client_address[0]}:{self.client_address[1]}")

            while not self.stop_event.is_set():  # Use the stop_event here
                try:
                    timeout = 1.0  # Timeout for select
                    ready_to_read, _, _ = select.select([self.request], [], [], timeout)
                    if self.request in ready_to_read:
                        self.data = self.request.recv(MAX_DATA_RECEIVE)
                        if not self.data:
                            print(f"Client {self.client_address} disconnected.")
                            self.remove_client()
                            break
                    
                    # Get number of received bytes
                    num_bytes = len(self.data)
                    if num_bytes == 0:
                        continue  # Skip processing if no data is received
                    
                    response = self.process_data(self.data)
                    if response is not None:
                        if self.request and self.request.fileno() != -1:
                            self.request.sendall(response)
                        else:
                            print(f"Socket {self.client_address} is closed or invalid.")
                            self.remove_client()
                except socket.timeout:
                    print(f"Timeout while reading from {self.client_address}. Closing connection.")
                    self.remove_client()
                    break
        except ConnectionResetError:
            print(f"Client {self.client_address} forcibly closed the connection.")
            self.remove_client()
        except Exception as e:
            print(f"An error occurred: {e}")
            self.remove_client()

    def process_data(self, data):
        if DEBUG:
            # Print the received data for debugging purposes
            print(f"DEBUG: Received data from {self.client_address}: {data}")
        with player_map_lock:
            if data == b'JOIN':
                if len(player_map) == 2:
                    return "e".encode()
                
                # Determine paddle position based on player order
                if len(player_map) == 0:
                    x_position = 3
                else:
                    x_position = pong.SCREEN_WIDTH - 23 - 3 # Right side for Player 2
                
                player = Player(
                    self.client_address[0],
                    self.client_address[1],
                    self.request,
                    x_position,
                    pong.SCREEN_HEIGHT // 2,
                    pong.SCREEN_HEIGHT,
                    pong.PADDLE_HEIGHT
                )
                player_map[player] = (self.client_address[0], self.client_address[1])
                print(f"Player {player} joined")
                
                if len(player_map) == 2:
                    print("Both players joined. Starting game...")
                    pong.set_players(*player_map.keys())  # Pass players to pong            
                return "o".encode()
            
            elif data == b'RUN':
                if len(player_map) != 2:
                    return "e".encode()
                # Send ball position and player positions to player
                players = list(player_map.keys())
                ball_x = pong.ball_x + C64_BORDER_WIDTH
                ball_y = pong.ball_y + C64_BORDER_HEIGHT
                pl1_x = players[0].get_pos_x() + C64_BORDER_WIDTH
                pl1_y = players[0].get_pos_y() + C64_BORDER_HEIGHT
                pl2_x = players[1].get_pos_x() + C64_BORDER_WIDTH
                pl2_y = players[1].get_pos_y() + C64_BORDER_HEIGHT

                sock = self.request  # Use the current request socket
                if sock and sock.fileno() != -1:  # Check if the socket is valid and open
                    try:
                        sock.sendall((
                            f"{ball_x},{ball_y},"
                            f"{pl1_x},{pl1_y},"
                            f"{pl2_x},{pl2_y},"
                        ).encode())
                        if DEBUG:
                            # Print the sent data for debugging purposes
                            print(f"DEBUG: Sent data to socket {sock.getpeername()}: {ball_x},{ball_y}:{pl1_x},{pl1_y}:{pl2_x},{pl2_y}")
                    except Exception as e:
                        print(f"Error while sending data to socket {sock.getpeername()}: {e}")
                else:
                    print(f"Socket {sock.getpeername()} is closed or invalid. Skipping.")
                return None
            
            elif data == b'JU':
                # Find the player who sent the data and move it up
                for player in player_map.keys():
                    if player.get_socket() == self.request:
                        player.move(-PADDLE_MOVE_SPEED)
                        break
                return None
            
            elif data == b'JD':
                # Find the player who sent the data and move it down
                for player in player_map.keys():
                    if player.get_socket() == self.request:
                        player.move(PADDLE_MOVE_SPEED)
                        break
                return None
            
            return "e".encode()

def run_tcp_server(server_class=socketserver.ThreadingTCPServer, handler_class=TCPRequestHandler, port=PORT, stop_event=None):
    class CustomTCPServer(server_class):
        def __init__(self, *args, **kwargs):
            self.stop_event = stop_event  # Pass stop_event to the handler
            super().__init__(*args, **kwargs)

        def finish_request(self, request, client_address):
            self.RequestHandlerClass(request, client_address, self, stop_event=self.stop_event)

    server_address = ('0.0.0.0', port)
    tcp_server = CustomTCPServer(server_address, handler_class)
    tcp_server.timeout = 1  # Set a timeout of 1 second for handle_request

    local_ip = get_local_ip()
    print(f'Starting TCP server on {local_ip}:{port}')
    
    try:
        while not stop_event.is_set():
            try:
                tcp_server.handle_request()  # Continuously handle incoming requests
            except Exception as e:
                print(f"Error while handling request: {e}")
    finally:
        # Close all client sockets and the server
        with player_map_lock:  # Ensure thread-safe cleanup
            for player in list(player_map.keys()):
                try:
                    sock = player.get_socket()
                    if sock:  # Ensure the socket is not None
                        sock.close()
                except Exception as e:
                    print(f"Error while closing socket for player {player}: {e}")
                finally:
                    del player_map[player]  # Remove the player from the map
        tcp_server.server_close()
        print("TCP server stopped.")

def listen_for_esc(stop_event):
    while not stop_event.is_set():
        if keyboard.is_pressed('esc'):
            print("ESC key pressed. Stopping server...")
            stop_event.set()
            break
        time.sleep(0.1)  # Add a small delay to prevent high CPU usage

def update_ball_thread(stop_event):
    """Thread function to update the ball 20 times per second."""
    while not stop_event.is_set():
        with player_map_lock:
            if len(player_map) == 2:  # Only update the ball if both players are connected
                pong.update_ball()
        time.sleep(0.05)  # Run 20 times per second (1/20 = 0.05 seconds)

def main():
    stop_event = threading.Event()
    
    tcp_thread = threading.Thread(target=run_tcp_server, kwargs={'stop_event': stop_event})
    esc_thread = threading.Thread(target=listen_for_esc, args=(stop_event,))
    ball_thread = threading.Thread(target=update_ball_thread, args=(stop_event,))  # New thread for updating the ball

    tcp_thread.start()
    esc_thread.start()
    ball_thread.start()  # Start the ball update thread

    tcp_thread.join()
    esc_thread.join()
    ball_thread.join()  # Wait for the ball update thread to finish

if __name__ == '__main__':
    main()