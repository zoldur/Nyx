# NYX Coin
Shell script to install an [Nyx Coin Masternode](https://www.nyxcoin.org/) on a Linux server running Ubuntu 16.04. Use it on your own risk.  

***
## Installation:  
```
wget -q https://raw.githubusercontent.com/zoldur/Nyx/master/nyx_install.sh
bash nyx_install.sh
```
***

## Desktop wallet setup  

After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps for Windows Wallet
1. Open the Nyx Coin Desktop Wallet.  
2. Go to RECEIVE and create a New Address: **MN1**  
3. Send **1000** NYX to **MN1**.  
4. Wait for 15 confirmations.  
5. Go to **Tools -> "Debug console - Console"**  
6. Type the following command: **masternode outputs**  
7. Edit **%APPDATA%\Nyx\masternode.conf** file  
8. Add the following entry:  
```
Alias Address Privkey TxHash Output_index  
```
* Alias: **MN1**  
* Address: **VPS_IP:PORT**  
* Privkey: **Masternode Private Key**  
* TxHash: **First value from Step 6**  
* Output index:  **Second value from Step 6**  
9. Save and close the file.  
10. Go to **Masternode Tab**. If you tab is not shown, please enable it from: **Settings - Options - Wallet - Show Masternodes Tab**  
11. Click **Update status** to see your node. If it is not shown, close the wallet and start it again.  
10. Click **Start All**  
***

## Usage:  

For security reasons **NyxCore** is installed under **nyx** user, hence you need to **su - nyx** before checking:    
```
NYX_USER=nyx #replace nyx with the MN username you want to check
su - $NYX_USER  
nyx-cli mnsync status  
nyx-cli getinfo  
```  
Also, if you want to check/start/stop **NyxCore** , run one of the following commands as **root**:
```
NYX_USER=nyx  #replace nyx with the MN username you want to check  
systemctl status $NYX_USER #To check the service is running. systemctl start $NYX_USER #To start Nyx service.
systemctl stop $NYX_USER #To stop Nyx service.  
systemctl is-enabled $NYX_USER #To check whetether Nyx service is enabled on boot or not.  
```  
***

## Donations:
  
Any donation is highly appreciated  

**NYX**: NTEoVQV8jrTZA5gfmpR1UvBAY3i4aLLKWz  
**BTC**: 1BzeQ12m4zYaQKqysGNVbQv1taN7qgS8gY  
**ETH**: 0x39d10fe57611c564abc255ffd7e984dc97e9bd6d  
**LTC**: LXrWbfeejNQRmRvtzB6Te8yns93Tu3evGf  
