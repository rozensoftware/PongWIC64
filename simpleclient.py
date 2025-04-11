import socket

SERVER_IP = "192.168.0.17"  # Replace with the server's IP address
SERVER_PORT = 6510       # Replace with the server's port

def main():
    try:
        # Create a TCP socket
        client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        client_socket.connect((SERVER_IP, SERVER_PORT))
        print(f"Connected to server at {SERVER_IP}:{SERVER_PORT}")

        while True:
            # Display menu for user input
            print("\nCommands:")
            print("1. JOIN - Join the game")
            print("2. RUN - Update game state")
            print("3. JU - Move paddle up")
            print("4. JD - Move paddle down")
            print("5. EXIT - Close the client")
            command = input("Enter your command: ").strip().upper()

            if command == "EXIT":
                print("Exiting client...")
                break

            # Send the command to the server
            client_socket.sendall(command.encode())

            # Receive and print the server's response
            response = client_socket.recv(256)
            print(f"Server response: {response.decode()}")

    except ConnectionRefusedError:
        print("Failed to connect to the server. Is it running?")
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        client_socket.close()
        print("Client socket closed.")

if __name__ == "__main__":
    main()