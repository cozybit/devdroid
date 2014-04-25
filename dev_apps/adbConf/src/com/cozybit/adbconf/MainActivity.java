package com.cozybit.adbconf;

import java.io.UnsupportedEncodingException;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Enumeration;

import com.cozybit.adbconf.utils.shell.CmdOutput;
import com.cozybit.adbconf.utils.shell.Shell;
import com.cozybit.adbconf.utils.shell.Shell.ShellException;

import android.os.Build;
import android.os.Bundle;
import android.app.Activity;
import android.app.AlertDialog;
import android.util.Log;
import android.view.View;
import android.widget.Button;

public class MainActivity extends Activity {

	private final static int USB_MODE = -1;
	private final static int TCP_MODE = 5555;

	private final static int SHELL_ERROR_DIALOG = 0;
	private final static int NO_OUTPUT_DIALOG = 1;
	private final static int SETPROP_ERROR_DIALOG = 2;
	private final static int ADB_ERROR_DIALOG = 3;
	private final static int IPSET_ERROR_DIALOG = 4;
	private final static int NETUP_ERROR_DIALOG = 5;
	private final static int NO_SERIAL_DIALOG = 6;
	
	private final static String IFACE_NAME = "eth0";
	private final static int NET_IP = 11;
	private final static int NET_MASK = 8;
	
	Button ethConfigButton;

	/**
	 * IMPORTANT: this app requires ROOT privileges in order to work.
	 * This means that your device has to be rooted!!! (Superuser.apk, etc)
	 */

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_main);
		ethConfigButton = (Button) findViewById(R.id.eth_button);
		String md5Serial = MD5(Build.SERIAL);
		Log.d("FUCK", "Build.SERIAL: " + Build.SERIAL);
		Log.d("FUCK", "md5Serial: " + md5Serial);
		Log.d("FUCK", "IP: " + generateIpFromStrMd5(NET_IP, Build.SERIAL) );
	}
	
	@Override
	public void onResume() {
		//Log.d("ADB_CONF", "onResume()!!!");
		//int visibility = isValidIface(IFACE_NAME)? View.VISIBLE:View.GONE;  
		//ethConfigButton.setVisibility(visibility);
		ethConfigButton.setVisibility(View.VISIBLE);
		super.onResume();
	}

	public void onAdbUSBButton(View view) {
		configAdbMode(USB_MODE);
	}

	public void onAdbTCPButton(View view) {
		configAdbMode(TCP_MODE);
	}
	
	public void onEthModeButton(View view) {
		if(Build.SERIAL != null && !Build.SERIAL.isEmpty() ) { 
			if( configEthernet() )
				configAdbMode(TCP_MODE);
		} else
			promptDialog(NO_SERIAL_DIALOG, null);			
	}

	private boolean configAdbMode(int port) {

		try {
			CmdOutput output = Shell.sudo("setprop service.adb.tcp.port " + port);
			if( output == null ) { promptDialog(NO_OUTPUT_DIALOG, null); return false; }
			if ( output.exitValue != 0 ) { promptDialog(SETPROP_ERROR_DIALOG, output.STDERR); return false; }
			output = Shell.sudo("stop adbd; start adbd");
			if( output == null ) { promptDialog(NO_OUTPUT_DIALOG, null); return false; }
			if ( output.exitValue != 0 ) promptDialog(ADB_ERROR_DIALOG, output.STDERR);
		} catch (ShellException e) {
			e.printStackTrace();
			promptDialog(SHELL_ERROR_DIALOG, null);
			return false;
		}
		
		return true;
	}
	
	//configure the Ethernet iface
	private boolean configEthernet() {

		String ip = generateIpFromStrMd5(NET_IP, Build.SERIAL);

		if(ip != null) { 
			try {
				CmdOutput output = Shell.sudo("ip address add dev " + IFACE_NAME + " " + ip.toString() + "/" + NET_MASK);
				if( output == null ) { promptDialog(NO_OUTPUT_DIALOG, null); return false; }
				if ( output.exitValue != 0 ) { promptDialog(IPSET_ERROR_DIALOG, output.STDERR); return false; }
				output = Shell.sudo("netcfg " + IFACE_NAME + " up");
				if( output == null ) { promptDialog(NO_OUTPUT_DIALOG, null); return false; }
				if ( output.exitValue != 0 ) { promptDialog(NETUP_ERROR_DIALOG, output.STDERR); return false; }
				return true;
			} catch (ShellException e) {
				e.printStackTrace();
				promptDialog(SHELL_ERROR_DIALOG, null);
			}
		}

		return false;
	}
	
	/* This function will generate an IP based on:
	 *   - A given net prefix
	 *   - The last 6characters of the md5sum of any str
	 */
	private String generateIpFromStrMd5(int netPrefix, String str) {
		
		if(str == null)
			return null;
		
		StringBuffer ip = new StringBuffer();
		ip.append(netPrefix);
		//get the first 6 characters of the serial number to create the ip
		String md5Serial = MD5(str);
		String serial = md5Serial.substring( (md5Serial.length()-6), md5Serial.length() );
		serial = serial.toLowerCase();		
		for (int offset = 0; offset < serial.length(); offset=offset+2 ) {
			String segment = serial.substring(offset, offset+2);
			ip.append(".");
			ip.append(Integer.parseInt(segment, 16));
		}

		return ip.toString();
	}
	
    //check if the mesh interface is up
    private boolean isValidIface(String ifaceName) {
    	try {
    		for(Enumeration<NetworkInterface> list = NetworkInterface.getNetworkInterfaces(); list.hasMoreElements();) {
                    NetworkInterface i = list.nextElement();
                    if( i.getDisplayName().equals(ifaceName) )
                    	return true;
            }
		} catch (SocketException e) {
			e.printStackTrace();
		}
    	return false;
    }
    
    private String MD5(String md5) {
    	try {
    		java.security.MessageDigest md = java.security.MessageDigest.getInstance("MD5");
	    	byte[] array = md.digest( md5.getBytes("UTF-8") );
	    	StringBuffer sb = new StringBuffer();
	    	for (int i = 0; i < array.length; ++i)
	    		sb.append(Integer.toHexString((array[i] & 0xFF) | 0x100).substring(1,3));
	    	return sb.toString();
    	} catch (java.security.NoSuchAlgorithmException e) {
    		e.printStackTrace();
    	} catch (UnsupportedEncodingException e) {
    		e.printStackTrace();
		}
    	return null;
    }

	private void promptDialog(int dialogId, String msg) {

        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setIcon(android.R.drawable.ic_dialog_alert);
        builder.setPositiveButton("Ok", null);

        switch (dialogId) {

		case SHELL_ERROR_DIALOG:
			builder.setTitle("Shell Error");
			builder.setMessage("An error occured while executing a shell command. Check the logcat ouput for more info.");
			break;

		case NO_OUTPUT_DIALOG:
			builder.setTitle("No Output Error");
			builder.setMessage("Executed cmd returned no ouput. Is your device rooted??");
			break;

		case SETPROP_ERROR_DIALOG:
			builder.setTitle("Setpropt Error");
			builder.setMessage("An error occured when setting the adb.tcp.prot property. Error: " + msg);
			break;

		case ADB_ERROR_DIALOG:
			builder.setTitle("Adb Error");
			builder.setMessage("An error occured while restarting adbd. Error: " + msg);
			break;
			
		case IPSET_ERROR_DIALOG:
			builder.setTitle("Ip Error");
			builder.setMessage("An error occured while configuren the ip address: " + msg);
			break;
			
		case NETUP_ERROR_DIALOG:
			builder.setTitle("Interface Error");
			builder.setMessage("An error occured while bringing the interface up: " + msg);
			break;
			
		case NO_SERIAL_DIALOG:
			builder.setTitle("No Serial Number");
			builder.setMessage("Error: the device does not have a serial number. The serial # is needed to create a valid IP address and configure the iface.");
			break;			
        }

        AlertDialog ad = builder.create();
        ad.show();
	}
}