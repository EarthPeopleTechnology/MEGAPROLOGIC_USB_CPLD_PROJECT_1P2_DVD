﻿using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.Threading;
using System.Runtime.InteropServices;
using System.Diagnostics;

namespace Data_Collector
{
    public partial class Data_Collector : Form
    {
        public Data_Collector()
        {
            InitializeComponent();

            for (int i = 0; i < EPTTransmitDevice.Length; ++i)
            {
                EPTTransmitDevice[i] = new Transfer();
            }

        }
		
        //Index to store device selection
        Int32 device_index;

        //Create a Receive object of the Transfer Class.
        Transfer EPTReceiveData = new Transfer();

        //Create an array of the Transfer Class for device
        Transfer[] EPTTransmitDevice = new Transfer[8];

        //Parameters
        public const byte TRIGGER_OUT_COMMAND = 0x1;
        public const byte TRANSFER_OUT_COMMAND = 0x2;
        public const byte BLOCK_OUT_COMMAND = 0x4;


        // Main object loader
        private void Data_Collector_Load (object sender, System.EventArgs e)
        {

            // Call the List Devices function
            ListDevices();
        }


        // Main connection function
        private unsafe Int32 ListDevices()
        {
            Int32 result;
            Int32 num_devices;
            Int32 iCurrentIndex;

            // Open the DLL
            result = EPT_AH_Open(null, null, null);
            if (result != 0)
            {
                MessageBox.Show("Could not attach to the ActiveHost library");
                return 0;
            }

            // Set debug mode
            //EPT_AH_SetDebugMode(1);

            // Query connected devices
            num_devices = EPT_AH_QueryDevices();

            //Prepare the Combo box for population
            iCurrentIndex = cmbDevList.SelectedIndex;
            cmbDevList.Items.Clear();

            // Go through all available devices
            for (device_index = 0; device_index < num_devices; device_index++)
            {
                String str;
                str = Marshal.PtrToStringAnsi((IntPtr)EPT_AH_GetDeviceName(device_index));
                cmbDevList.Items.Add(str);
            }
            return 0;
        }

        // Open the device
        public unsafe Int32 OpenDevice()
        {
            device_index = (int)cmbDevList.SelectedIndex;
            if (EPT_AH_OpenDeviceByIndex(device_index) == 0)
            {
                String message = "Could not open device " + Marshal.PtrToStringAnsi((IntPtr)EPT_AH_GetDeviceName(device_index))
                                                          + ", "
                                                          + Marshal.PtrToStringAnsi((IntPtr)EPT_AH_GetDeviceSerial(device_index));
                MessageBox.Show(message);
                return 0;
            }

            // Make the opened device the active device
            if (EPT_AH_SelectActiveDeviceByIndex(device_index) == 0)
            {
                String message = "Error selecting device: %s " + Marshal.PtrToStringAnsi((IntPtr)EPT_AH_GetLastError());
                MessageBox.Show(message);
                return 0;
            }

            // Register the read callback function
            RegisterCallBack();
            btnOpenDevice.Enabled = false;
            btnCloseDevice.Enabled = true;
            return 0;
        }

        private void btnOpenDevice_Click(object sender, EventArgs e)
        {
            //Open the Device
            OpenDevice();
            lblDeviceConnected.Text = "Device Connected";
        }

        private void btnCloseDevice_Click(object sender, EventArgs e)
        {
            EPT_AH_CloseDeviceByIndex(device_index);
            btnOpenDevice.Enabled = true;
            btnCloseDevice.Enabled = false;

            lblDeviceConnected.Text = " ";
        }

        private void btnWriteByte_Click(object sender, EventArgs e)
        {
            int address_to_device;
            address_to_device = Convert.ToInt32(tbAddress.Text);
            EPT_AH_SendTransferControlByte((char)2, (char)1);
        }

        private void btnTransferReset_Click(object sender, EventArgs e)
        {
            int address_to_device;
            address_to_device = Convert.ToInt32(tbAddress.Text);
            EPT_AH_SendTransferControlByte((char)address_to_device, (char)0);
        }

        private void btnOk_Click(object sender, EventArgs e)
        {
            EPT_AH_CloseDeviceByIndex(device_index);
            btnOpenDevice.Enabled = true;
            btnCloseDevice.Enabled = false;

            lblDeviceConnected.Text = "";
            Application.Exit();
        }

        private void btnCancel_Click(object sender, EventArgs e)
        {
            EPT_AH_CloseDeviceByIndex(device_index);
            btnOpenDevice.Enabled = true;
            btnCloseDevice.Enabled = false;

            lblDeviceConnected.Text = "";
            Application.Exit();
        }

        private void EPTParseReceive()
        {
            switch (EPTReceiveData.Command)
            {
                case TRANSFER_OUT_COMMAND:
                    TransferOutReceive();
                    break;
                default:
                    break;
            }
        }


        public void TransferOutReceive()
        {
            string WriteRcvChar = "";
            WriteRcvChar = String.Format("{0}", (int)EPTReceiveData.Payload);
            tbDataBytes.AppendText(WriteRcvChar + " ");
        }

        private void btnResetBlock_Click(object sender, EventArgs e)
        {
            tbDataBytes.Clear();
        }
		
    }
	
    public class Transfer
    {
        public int Command;
        public int Address;
        public int Length;
        public int Payload;
        public byte[] cBlockBuf;
        public bool TransferPending;
        public uint Repititions;

        public Transfer()
        {
            Command = 0;
            Address = 0;
            Length = 0;
            Payload = 0;
            TransferPending = false;
            Repititions = 0;
        }

    }
	
}
