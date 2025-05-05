#!/bin/bash

# === Default values ===
USERNAME=""
PASSWORD=""
ADD_SUDO=false

# === Help function ===
usage() {
    echo "Usage: $0 [--username <name>] [--password <password>] [--sudo]"
    echo "  If no arguments are provided, the script will prompt for input."
    exit 1
}

# === Parse command-line arguments ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --username)
            USERNAME="$2"
            shift 2
            ;;
        --password)
            PASSWORD="$2"
            shift 2
            ;;
        --sudo)
            ADD_SUDO=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# === Prompt for input if not provided ===
if [ -z "$USERNAME" ]; then
    read -p "Enter username: " USERNAME
fi

if [ -z "$PASSWORD" ]; then
    read -s -p "Enter password for user: " PASSWORD
    echo ""
fi

read -p "Grant sudo privileges to this user? (y/N): " sudo_input
if [[ "$sudo_input" =~ ^[Yy]$ ]]; then
    ADD_SUDO=true
fi

# === Create the user ===
echo "[+] Creating user '$USERNAME'..."

if id "$USERNAME" &>/dev/null; then
    echo "[!] User '$USERNAME' already exists."
else
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "[+] User '$USERNAME' has been created with a password."
fi

# === Generate SSH keypair ===
USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
KEY_NAME="id_rsa"

mkdir -p "$SSH_DIR"
ssh-keygen -t rsa -b 2048 -f "$SSH_DIR/$KEY_NAME" -N "" -q
cat "$SSH_DIR/$KEY_NAME.pub" > "$SSH_DIR/authorized_keys"

# === Set proper permissions ===
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/$KEY_NAME"
chmod 644 "$SSH_DIR/$KEY_NAME.pub"

echo "[+] SSH keypair has been generated and configured for user '$USERNAME'."

# === Add to sudo group if requested ===
if [ "$ADD_SUDO" = true ]; then
    usermod -aG wheel "$USERNAME"
    echo "[+] User '$USERNAME' has been added to the sudo group."
fi

# === Ensure SSH allows both password and key authentication ===
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
systemctl restart sshd

# === Output private key for user ===
echo "======================================"
echo "🔐 PRIVATE KEY FOR USER $USERNAME:"
echo "======================================"
cat "$SSH_DIR/$KEY_NAME"
echo "======================================"
echo "💡 Save this private key to use SSH: ssh -i <private_key_file> $USERNAME@<IP>"
echo "[✔] Done!"