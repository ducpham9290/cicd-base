#!/bin/bash

# === Default values ===
USERNAME=""
PASSWORD=""
ADD_SUDO=false

# === Hàm hiển thị trợ giúp ===
usage() {
    echo "Usage: $0 [--username <name>] [--password <password>] [--sudo]"
    echo "  Nếu không truyền tham số, script sẽ hỏi thông tin khi chạy."
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

# === Nhập thông tin nếu chưa có ===
if [ -z "$USERNAME" ]; then
    read -p "Nhập tên user: " USERNAME
fi

if [ -z "$PASSWORD" ]; then
    read -s -p "Nhập mật khẩu cho user: " PASSWORD
    echo ""
fi

read -p "Cấp quyền sudo cho user này? (y/N): " sudo_input
if [[ "$sudo_input" =~ ^[Yy]$ ]]; then
    ADD_SUDO=true
fi

# === Tạo user ===
echo "[+] Tạo user '$USERNAME'..."

if id "$USERNAME" &>/dev/null; then
    echo "[!] User '$USERNAME' đã tồn tại."
else
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "[+] User '$USERNAME' đã được tạo với mật khẩu."
fi

# === Tạo SSH keypair ===
USER_HOME="/home/$USERNAME"
SSH_DIR="$USER_HOME/.ssh"
KEY_NAME="id_rsa"

mkdir -p "$SSH_DIR"
ssh-keygen -t rsa -b 2048 -f "$SSH_DIR/$KEY_NAME" -N "" -q
cat "$SSH_DIR/$KEY_NAME.pub" > "$SSH_DIR/authorized_keys"

# === Phân quyền đúng ===
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/$KEY_NAME"
chmod 644 "$SSH_DIR/$KEY_NAME.pub"

echo "[+] SSH key đã được tạo và cấu hình cho user '$USERNAME'."

# === Cấp quyền sudo nếu được yêu cầu ===
if [ "$ADD_SUDO" = true ]; then
    usermod -aG wheel "$USERNAME"
    echo "[+] Đã thêm '$USERNAME' vào nhóm sudo (wheel)."
fi

# === Cấu hình SSH cho phép cả password và key ===
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
systemctl restart sshd

# === In private key ===
echo "======================================"
echo "🔐 PRIVATE KEY DÀNH CHO USER $USERNAME:"
echo "======================================"
cat "$SSH_DIR/$KEY_NAME"
echo "======================================"
echo "💡 Lưu key này để SSH: ssh -i <private_key_file> $USERNAME@<IP>"
echo "[✔] Hoàn tất!"