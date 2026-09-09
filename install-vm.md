# Cilium Lab — Instalação da Máquina Virtual

## Passo a passo de instalação

### 1. Baixar a ISO do Ubuntu Server

Baixe a versão **Ubuntu Server 24.04.x**:

https://ubuntu.com/download/server

O arquivo esperado será semelhante a:

```text
ubuntu-24.04.x-live-server-amd64.iso
```

---

### 2. Criar a máquina virtual no Virtual Machine Manager

Abra o **Virtual Machine Manager**.

1. Clique em **File**.

2. Clique em **New Virtual Machine**.

3. Selecione:

   **Local install media (ISO image or CDROM)**

4. Clique em **Forward**.

5. Clique em **Browse**.

6. Selecione o arquivo:

   ```text
   ubuntu-24.04.x-live-server-amd64.iso
   ```

7. Caso o Virtual Machine Manager não detecte automaticamente o sistema operacional **Ubuntu 24.04**, selecione manualmente:

   ```text
   Ubuntu 24.04 LTS
   ```

8. Clique em **Forward**.

---

### 3. Configurar memória e CPU

Configure a máquina virtual com:

| Recurso |               Valor |
| ------- | ------------------: |
| RAM     | **8192 MiB (8 GB)** |
| CPUs    |               **4** |

Clique em **Forward**.

---

### 4. Configurar o disco

Configure o tamanho do disco como:

```text
40 GB
```

Clique em **Forward**.

---

### 5. Configurar nome e rede

Configure:

* **Nome da VM:** `cilium-lab`
* **Network:** `default`

A rede deve aparecer como algo equivalente a:

```text
Virtual network 'default': NAT
```

Marque:

```text
Customize configuration before install
```

Clique em **Finish**.

---

## 6. Verificar a configuração de hardware

Antes de iniciar a instalação, verifique se a VM está configurada da seguinte forma:

### CPU e memória

```text
CPUs: 4
Memory: 8192 MiB
```

### Disco

```text
Disk 1
Bus: VirtIO
```

### Rede

```text
Network source:
Virtual network 'default': NAT

Device model:
virtio
```

### Display e vídeo

Configure:

```text
Display: SPICE
Video: Virtio
```

Depois, clique em:

**Begin Installation**

---

# 7. Instalação do Ubuntu Server

Durante a instalação do Ubuntu:

### Inicialização

Selecione:

```text
Try or Install Ubuntu Server
```

### Idioma

Deixe:

```text
Language: English
```

### Teclado

Configure:

```text
Keyboard: Portuguese (Brazil)
```

### Tipo de instalação

Deixe:

```text
Installation Type: Ubuntu Server
```

O Ubuntu deverá detectar automaticamente a interface de rede.

---

## 8. Configuração do armazenamento

Quando aparecer:

**Guided storage configuration**

Selecione:

```text
Use an entire disk
```

---

## 9. Criar o usuário

Na etapa de criação do usuário, utilize:

| Campo           | Valor                  |
| --------------- | ---------------------- |
| **Your name**   | `aluno-labpesq-cilium` |
| **Server name** | `cilium-lab`           |
| **Username**    | `aluno-labpesq-cilium` |
| **Password**    | `<Senha da VM>`         |

O hostname da máquina pode ser:

```text
cilium-lab
```

---

## 10. Instalar o OpenSSH Server

Quando aparecer:

**Install OpenSSH server**

Marque a opção para instalar o **OpenSSH Server**.

Isso permitirá acessar a VM remotamente através de SSH.

---

## 11. Featured Server Snaps

Quando aparecer a tela:

**Featured Server Snaps**

**Não marque nenhuma das opções.**

Continue a instalação normalmente.
