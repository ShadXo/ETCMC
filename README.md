# ETCMC Scripts

**Ethereum Classic Mining Community (ETCMC)** — Node Scripts to simplify setup, management, monitoring, and updates.

---

## 📖 Description

ETCMC Scripts provide a lightweight way to run and manage ETCMC nodes.  
You can use the interactive menu or run individual scripts directly for specific tasks like setup, restart, monitoring, or updates.

---

## 🚀 Quick Start

Download and run the main menu:

```
wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc.sh -O etcmc.sh && chmod +x etcmc.sh && ./etcmc.sh
```

Run the menu if already downloaded:

```
./etcmc.sh
```

---

## ⚙️ Usage

You can run ETCMC scripts either through the interactive menu (`etcmc.sh`) or directly via individual commands.

### Menu-based execution

Run the interactive menu:

```
./etcmc.sh
```

---

### Direct script execution

- `-p` specifies the project name (example: `etcmc`)  
- `-n` specifies the node alias (example: `n1`)  

👉 **Important notes:**  
- If no alias (`-n`) is provided, the script will run for all nodes — unless the alias is **mandatory** (e.g., `etcmc_remove.sh` requires `-n`).  
- Right now, only **one node per machine** is supported. This limitation exists because of the way the **ETCMC Client** currently runs.

Examples:

- **List nodes**  
  ```
  ./etcmc_list.sh -p etcmc
  ```

- **Restart node**  
  ```
  ./etcmc_restart.sh -p etcmc -n n1
  ```

- **Stop node**  
  ```
  ./etcmc_stop.sh -p etcmc -n n1
  ```

- **Set up new node**  
  ```
  ./etcmc_setup.sh -p etcmc
  ```

- **Remove node (alias required)**  
  ```
  ./etcmc_remove.sh -p etcmc -n n1
  ```

- **Update node**  
  ```
  ./update_node.sh -p etcmc
  ```

- **Configure Telegram monitoring**  
  ```
  ./etcmc_monitoring.sh -p etcmc -n n1
  ```

---

## 📂 Files

| File                   | Purpose                                                                 |
|------------------------|-------------------------------------------------------------------------|
| **etcmc.sh**           | Main menu script to manage ETCMC nodes                                  |
| **etcmc_list.sh**      | Lists available ETCMC nodes                                             |
| **etcmc_remove.sh**    | Removes a node from the system                                          |
| **etcmc_restart.sh**   | Restarts a specific ETCMC node                                          |
| **etcmc_setup.sh**     | Sets up a new ETCMC node                                                |
| **etcmc_stop.sh**      | Stops a running node                                                    |
| **update_node.sh**     | Updates a node if its version is older than the latest available        |
| **etcmc_monitoring.sh**| Configures the ETCMC Nodecheck Telegram Bot for node monitoring         |
---

## 🛡️ Notes

- Always review scripts before piping them into `sh` for security reasons.
- Tested on Linux environments (Ubuntu/Debian recommended).
- Contributions and improvements are welcome!

---

## 🤝 Contributing

1. Fork the repo  
2. Create a feature branch: `git checkout -b feature-name`  
3. Commit changes: `git commit -m "Add feature"`  
4. Push to branch: `git push origin feature-name`  
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License.  
See [LICENSE](LICENSE) for details.
