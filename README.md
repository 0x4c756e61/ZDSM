# ⚡ZDSM ⚡ - Zig Implementation of BDSM Protocol

![GitHub License](https://img.shields.io/github/license/0x454d505459/ZDSM)
![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/0x454d505459/ZDSM/total)
![Static Badge](https://img.shields.io/badge/language-Zig-F7A41D)

ZDSM is a ⚡blazingly fast ⚡ and efficient implementation of the BDSM (Basic Data Server Monitoring) protocol. It is designed to monitor your server's health with minimal impact, focusing on speed and modularity.

## Key Features

- **⚡Blazingly Fast ⚡:** ZDSM ensures swift and responsive server monitoring.
- **Efficient Implementation:** Minimal impact on server resources for optimal performance.
- **Modular Design:** Easily customizable with a pluging system. (not yet available)
- **BDSM Protocol:** Implements the BDSM protocol for simple server monitoring.

## Getting Started

### Prerequisites

- **Linux Compatibility:** Currently, ZDSM does not support Windows due to underlying library limitations. If you need to run ZDSM on Windows, you can use the Windows Subsystem for Linux (WSL), but please note that this may incur a performance cost.
- **Glibc Dependency:** Ensure that your system uses the GNU implementation of the C library (Glibc). If your system relies on a different libc implementation, you will need to compile ZDSM manually to ensure compatibility.

### Installation

#### Automatic Installation

For a quick and automated installation, you can use the following one-liner in your terminal. This command will download and execute the installation script:

```bash
sh <(curl -sSf https://raw.githubusercontent.com/0x454d505459/ZDSM/main/install.sh)
```

Quick note: make sure you always check the scripts before executing them

#### Manual Installation

1. **Get the Latest Release:**
   - Download the latest [release](https://github.com/0x454d505459/ZDSM/releases) or compile it yourself.

2. **Set Execute Permission:**
   - Make sure the binary has the execute permission:
     ```bash
     chmod +x zdsm
     ```

3. **Move Binary to /usr/bin:**
   - Move the binary to the `/usr/bin` directory:
     ```bash
     sudo mv zdsm /usr/bin
     ```

4. **Run ZDSM:**
   - You can now run ZDSM by executing the following command in your terminal:
     ```bash
     zdsm
     ```

5. **Optional: Create Your Service File:**
   - If needed, you may want to create your own service file based on your system's requirements.

### Usage

To retrieve information from your server, you'll need a client that supports the new BDSM protocol. As of now, the official client is undergoing a complete rewrite and is not yet available.However, if necessary, an adapted version of the old client has been modified to use the new protocol. You can find this version available in [this fork](https://github.com/0x454d505459/bdsm-client-v1.5/).

In the meantime, you can still query the server using tools like `curl` or `xh` in your terminal. Here's an example using `curl`:

```bash
curl -H "Authorization: Bearer <your-password>" http://localhost:3040/api
```
Replace `<your-password>` with your actual server password.

### Configuration

You can customize your ZDSM server by editing the following environment variables.

- **PORT (Default: 3040):**
  - Set the port on which the ZDSM server will run.

- **SERVER_NAME (Default: "Unnamed server"):**
  - Provide a name for your server.

- **PASSWORD (Default: "admin"):**
  - Set the password for server authentication.

Additionally, ZDSM follows a specific configuration lookup order:

1. **Look for `.env` File:**
   - ZDSM first looks for a file named `.env` next to the executable. If found, it will use the configuration from this file.

2. **Fallback to Environment Variables:**
   - If no `.env` file is found, ZDSM will check for the specified environment variables. You can set these directly in your environment.

3. **Default Configuration:**
   - If neither an `.env` file nor environment variables are provided, ZDSM will fallback to the hardcoded configuration.

### Compiling

If you prefer to compile ZDSM from source for various reasons, follow these steps:

1. **Clone the Project:**
   - Clone the ZDSM project from the GitHub repository:
     ```bash
     git clone https://github.com/0x454d505459/ZDSM.git
     ```

2. **Build the Project:**
   - Navigate to the project directory and run the build step using Zig:
     ```bash
     cd ZDSM
     zig build
     ```

3. **Locate the Binary:**
   - After the build process completes, you can find the ZDSM binary in the following path:
     ```bash
     zig-out/bin/ZDSM
     ```

### Contributing

Feel free to contribute to the development of ZDSM by opening issues or pull requests on the GitHub repository.

### License

This project is licensed under the [AGPLv3 license](https://github.com/0x454d505459/ZDSM/blob/main/LICENSE) 
