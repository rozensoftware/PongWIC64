class Player:
    def __init__(self, ip, port, socket, x, y, screen_height, paddle_height):
        self.ip = ip
        self.port = port
        self.socket = socket
        self.y = y
        self.x = x
        self.screen_height = screen_height
        self.paddle_height = paddle_height

    def move(self, dy):
        """Move the paddle by a given delta Y."""
        if 0 <= self.y + dy <= self.screen_height - self.paddle_height:
            self.y += dy

    def get_socket(self):
        return self.socket

    def get_pos_x(self):
        return self.x
    
    def get_pos_y(self):
        return self.y
    
    def __repr__(self):
        return f"Player({self.ip}:{self.port}, x={self.x}, y={self.y})"

    def __hash__(self):
        # Use a tuple of IP and port to uniquely identify the player
        return hash((self.ip, self.port))

    def __eq__(self, other):
        # Compare IP and port to determine equality
        if isinstance(other, Player):
            return self.ip == other.ip and self.port == other.port
        return False
