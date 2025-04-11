import random

# Screen dimensions
SCREEN_WIDTH = 320
SCREEN_HEIGHT = 200

# Paddle and ball settings
PADDLE_HEIGHT = 20
PADDLE_WIDTH = 3
BALL_SIZE = 6

# Ball speed
BALL_SPEED = 3

# Ball properties
ball_x = SCREEN_WIDTH // 2
ball_y = SCREEN_HEIGHT // 2
ball_dx = BALL_SPEED
ball_dy = 1

player1 = None
player2 = None

def set_players(p1, p2):
    """Set the player objects."""
    global player1, player2
    player1 = p1
    player2 = p2

def move_player(player, dy):
    """Move a player's paddle by a given delta Y."""
    player.move(dy)

def update_ball():
    """Update ball position and handle collisions."""
    global ball_x, ball_y, ball_dx, ball_dy
    ball_x += ball_dx
    ball_y += ball_dy

    # Bounce off top and bottom walls
    if ball_y <= 0 or ball_y >= SCREEN_HEIGHT - BALL_SIZE:
        ball_dy *= -1

    # Bounce off paddles
    if (ball_x <= PADDLE_WIDTH and player1.y <= ball_y < player1.y + PADDLE_HEIGHT) or \
       (ball_x >= SCREEN_WIDTH - PADDLE_WIDTH - BALL_SIZE and player2.y <= ball_y < player2.y + PADDLE_HEIGHT):
        ball_dx *= -1

        # Adjust angle based on where the ball hits the paddle
        paddle_center = player1.y + PADDLE_HEIGHT // 2 if ball_x <= PADDLE_WIDTH else player2.y + PADDLE_HEIGHT // 2
        offset = (ball_y + BALL_SIZE // 2) - paddle_center
        ball_dy = offset // 5
    # Reset ball if it goes out of bounds
    elif ball_x < 0 or ball_x >= SCREEN_WIDTH:
        ball_x, ball_y = SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2
        ball_dx = random.choice([-BALL_SPEED, BALL_SPEED])  # Randomize horizontal direction
        ball_dy = random.choice([-1, 1])  # Randomize vertical direction
