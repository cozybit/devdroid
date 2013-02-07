package com.cozybit.adbconf;

import com.cozybit.adbconf.utils.shell.CmdOutput;
import com.cozybit.adbconf.utils.shell.Shell;
import com.cozybit.adbconf.utils.shell.Shell.ShellException;

import android.os.Bundle;
import android.app.Activity;
import android.app.AlertDialog;
import android.view.View;

public class MainActivity extends Activity {

	private final static int USB_MODE = -1;
	private final static int TCP_MODE = 5555;

	private final static int SHELL_ERROR_DIALOG = 0;
	private final static int NO_OUTPUT_DIALOG = 1;
	private final static int SETPROP_ERROR_DIALOG = 2;
	private final static int ADB_ERROR_DIALOG = 3;

	/**
	 * IMPORTANT: this app requires ROOT privileges in order to work.
	 * This means that your device has to be rooted!!! (Superuser.apk, etc)
	 */

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_main);
	}

	public void onAdbUSBButton(View view) {
		configAdbMode(USB_MODE);
	}

	public void onAdbTCPButton(View view) {
		configAdbMode(TCP_MODE);
	}

	private void configAdbMode(int port) {

		try {
			CmdOutput output = Shell.sudo("setprop service.adb.tcp.port " + port);
			if( output == null ) { promptDialog(NO_OUTPUT_DIALOG, null); return; }
			if ( output.exitValue != 0 ) { promptDialog(SETPROP_ERROR_DIALOG, output.STDERR); return; }
			output = Shell.sudo("stop adbd; start adbd");
			if( output == null ) { promptDialog(NO_OUTPUT_DIALOG, null); return; }
			if ( output.exitValue != 0 ) promptDialog(ADB_ERROR_DIALOG, output.STDERR);
		} catch (ShellException e) {
			e.printStackTrace();
			promptDialog(SHELL_ERROR_DIALOG, null);
		}
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
        }

        AlertDialog ad = builder.create();
        ad.show();
	}
}