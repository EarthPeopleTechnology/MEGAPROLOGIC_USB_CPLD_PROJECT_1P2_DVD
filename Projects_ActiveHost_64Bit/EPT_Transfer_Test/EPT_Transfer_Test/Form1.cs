using System;
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


namespace EPT_Transfer_Test
   {
   public partial class EPT_Transfer_Test : Form
      {

       public EPT_Transfer_Test()
      {
          InitializeComponent();

          btnBlkCompare8.Enabled = false;
          btnBlkCompare16.Enabled = false;
          btnTrigger1.Enabled = false;
          btnTrigger2.Enabled = false;
          btnTrigger3.Enabled = false;
          btnTrigger4.Enabled = false;
          btnLEDReset.Enabled = false;

          for (int i = 0; i < EPTTransmitDevice.Length; ++i)
          {
              EPTTransmitDevice[i] = new Transfer();
          }

          rbtnRepitions.Checked = true;
          rbtnInfinite.Checked = false;
      }

       //Index to store device selection
      Int32 device_index;

      //Create a Receive object of the Transfer Class.
      Transfer EPTReceiveData = new Transfer();

      //Eight Byte block for Block Transfers
      byte[] block_8_in_payload = new byte[8] { 0x32, 0x56, 0xe1, 0x6b, 0xc0, 0x7d, 0x89, 0x2e };
      byte[] block_16_in_payload = new byte[16] { 0x32, 0x56, 0xe1, 0x6b, 0xc0, 0x7d, 0x89, 0x2e, 0xb2, 0x05, 0x27, 0xf7, 0x99, 0x37, 0x42, 0xad };
      byte[] block_in_payload ;

      //Create an array of the Transfer Class for device
      Transfer[] EPTTransmitDevice = new Transfer[8];

      //Block Transfer and Loop counter
      int BlockCount = 0;
      int LoopCount = 0;

      //Block Transfer Control 
      public bool BlockTransferInfinite = false;
      public bool BlockTransferReps = false;
      public bool BlockTransferStop = false;

       //String to Hold payload
       public String PayloadString = "";

       //Parameters
       public const byte TRIGGER_OUT_COMMAND = 0x1;
       public const byte TRANSFER_OUT_COMMAND = 0x2;
       public const byte BLOCK_OUT_COMMAND = 0x4;

       //Value to hold the errors in Block Compares
       public int BlockErrorCount=0;
       public bool EnableLogFile=false;
      
      // Main object loader
       private void EPT_Transfer_Test_Load(object sender, System.EventArgs e)
         {

         // Call the List Devices function
         ListDevices();
         }

      // Main connection function
      private unsafe Int32 ListDevices ()
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
          else
          {
              btnBlkCompare8.Enabled = true;
              btnBlkCompare16.Enabled = true;
              btnTrigger1.Enabled = true;
              btnTrigger2.Enabled = true;
              btnTrigger3.Enabled = true;
              btnTrigger4.Enabled = true;
              btnLEDReset.Enabled = true;
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
      }

      private void btnCloseDevice_Click(object sender, EventArgs e)
      {
      if (EPT_AH_CloseDeviceByIndex(device_index) != 0)
         {
         btnBlkCompare8.Enabled = false;
         btnBlkCompare16.Enabled = false;
         btnTrigger1.Enabled = false;
         btnTrigger2.Enabled = false;
         btnTrigger3.Enabled = false;
         btnTrigger4.Enabled = false;
         btnLEDReset.Enabled = false;
         }
      btnOpenDevice.Enabled = true;
      btnCloseDevice.Enabled = false;
      }

      private void btnWriteByte_Click(object sender, EventArgs e)
      {
          int value;
          int address_to_device;
          //string ibyte,
          string ibyte = tbNumBytes.Text;/*Convert.ToInt32(tbNumBytes.Text);*/
          address_to_device = Convert.ToInt32(tbAddress.Text);

          int.TryParse(ibyte, out value);
          EPT_AH_SendByte(address_to_device, (char)value);
      }

      private void btnWriteMultiByte_Click(object sender, EventArgs e)
      {
          int value;
          int i, address_to_device;
          address_to_device = Convert.ToInt32(tbAddress.Text);
          string[] result = tbWriteMultiByte.Text.Split(' ', ',', '\n');
          for (i = 0; i < result.Length; i++)
          {
              int.TryParse(result[i], out value);

              EPT_AH_SendByte(address_to_device, (char)Convert.ToInt32(value/*result[i]*/));
              Thread.Sleep(1);
          }

      }

       private void btnLoopBack_Click(object sender, EventArgs e)
      {
          EPT_AH_SendTransferControlByte((char)2, (char)1);
      }

      private void btnTrigger1_Click(object sender, EventArgs e)
      {
          EPT_AH_SendTrigger((byte) 1);
      }

      private void btnTrigger2_Click(object sender, EventArgs e)
      {
          EPT_AH_SendTrigger((byte)2);
      }

      private void btnTrigger3_Click(object sender, EventArgs e)
      {
          EPT_AH_SendTrigger((byte)4);
      }

      private void btnTrigger4_Click(object sender, EventArgs e)
      {
          EPT_AH_SendTrigger((byte)8);
      }

      private void btnLEDReset_Click(object sender, EventArgs e)
      {
          EPT_AH_SendTransferControlByte((char)2,(char)4);
          Thread.Sleep(1);
          EPT_AH_SendTransferControlByte((char)2, (char)0);
      }

      private void rbtnInfinite_CheckedChanged(object sender, EventArgs e)
      {
          BlockTransferInfinite = true;
          BlockTransferReps = false;
      }

      private void rbtnRepitions_CheckedChanged(object sender, EventArgs e)
      {
          BlockTransferInfinite = false;
          BlockTransferReps = true;
      }

       private void btnStopBlockTransfer_Click(object sender, EventArgs e)
       {
           BlockTransferStop = true;
       }
       
      private void btnResetTriggerOut_Click(object sender, EventArgs e)
      {
          EPT_AH_SendTransferControlByte((char)2, (char)8);
          Thread.Sleep(1);
          EPT_AH_SendTransferControlByte((char)2,(char)0);
          Thread.Sleep(1);
      }

      private void btnUserBlk_Click(object sender, EventArgs e)
      {
          int value;
          if (tbBlockSend.Text.Trim().Length == 0) return;
          int BlockAddress = (int)Convert.ToInt32(tbBlockRcvAddress.Text);
          uint BlockRepitions = (uint)Convert.ToInt32(tbRepitions.Text);
          if (EPTTransmitDevice[BlockAddress].TransferPending)
              return;

          int i, address_to_device;
          address_to_device = Convert.ToInt32(tbAddress.Text);
          string[] result = tbBlockSend.Text.Split(' ', ',' , '\n');
          block_in_payload = new byte[result.Length];

          for (i = 0; i < result.Length; i++)
          {
              int.TryParse(result[i], out value);
              block_in_payload[i] = Convert.ToByte(value);// Convert.ToByte(result[i]);
          }

          EPTTransmitDevice[BlockAddress].Address = BlockAddress;
          EPTTransmitDevice[BlockAddress].Length = result.Length;
          EPTTransmitDevice[BlockAddress].Repititions = BlockRepitions;
          BlockCount = 0;
          LoopCount = 0;
          BlockErrorCount = 0;
          BlockTransferStop = false;

          Thread t = new Thread(new ParameterizedThreadStart(BlockCompare));
          t.Start(BlockAddress);

      }

      
       private void btnBlkCompare8_Click(object sender, EventArgs e)
      {
          int BlockAddress = (int)Convert.ToInt32(tbBlockRcvAddress.Text);
          int BlockLength = 8;
          uint BlockRepitions = (uint)Convert.ToInt32(tbRepitions.Text);
          if (EPTTransmitDevice[BlockAddress].TransferPending)
              return;
          EPTTransmitDevice[BlockAddress].Address = BlockAddress;
          EPTTransmitDevice[BlockAddress].Length = BlockLength;
          EPTTransmitDevice[BlockAddress].Repititions = BlockRepitions;
          BlockCount = 0;
          LoopCount = 0;
          BlockErrorCount = 0;
          BlockTransferStop = false;
          block_in_payload = block_8_in_payload;

          Thread t = new Thread(new ParameterizedThreadStart(BlockCompare));
          t.Start(BlockAddress);
      }

      private void btnBlkCompare16_Click(object sender, EventArgs e)
      {
          int BlockAddress = (int)Convert.ToInt32(tbBlockRcvAddress.Text);
          int BlockLength = 16;
          uint BlockRepitions = (uint)Convert.ToInt32(tbRepitions.Text);
          if (EPTTransmitDevice[BlockAddress].TransferPending)
              return;
          EPTTransmitDevice[BlockAddress].Address = BlockAddress;
          EPTTransmitDevice[BlockAddress].Length = BlockLength;
          EPTTransmitDevice[BlockAddress].Repititions = BlockRepitions;
          BlockCount = 0;
          LoopCount = 0;
          BlockErrorCount = 0;
          BlockTransferStop = false;
          block_in_payload = block_16_in_payload;

          Thread t = new Thread(new ParameterizedThreadStart(BlockCompare));
          t.Start(BlockAddress);

      }

       public unsafe void BlockCompare(object data)
      {
          int BlockAddress = (int)data;
          byte[] cBuf = new Byte[EPTTransmitDevice[BlockAddress].Length];

          if ((EPTTransmitDevice[BlockAddress].Repititions > 0) & !EPTTransmitDevice[BlockAddress].TransferPending & !BlockTransferStop)
          {
              //Select the Active Device
              EPT_AH_SelectActiveDeviceByIndex(device_index);
              //Set the EPTTransmitDevice object TransferPending to true.
              //This will prevent multiple writes to the device until
              //the device responds to the current write.
              EPTTransmitDevice[BlockAddress].TransferPending = true;
              //Copy the dummy data to the buffer to be transferred.
              Buffer.BlockCopy(block_in_payload, 0, cBuf, 0, EPTTransmitDevice[BlockAddress].Length);
              fixed (byte* pBuf = cBuf)
              {
                  //Send the dummy data to the Active Device
                  int xx = EPT_AH_SendBlock(EPTTransmitDevice[BlockAddress].Address, (void*)pBuf, (uint)EPTTransmitDevice[BlockAddress].Length);
              }
              //Send the Block Loop Back command
              Thread.Sleep(1);
              EPT_AH_SendTransferControlByte((char)2, (char)2);
              //Send the transfer FIFO to the Active Host command
              Thread.Sleep(1);
              EPT_AH_SendTrigger((byte) 128);
              //Reset all commands
              Thread.Sleep(1);
              EPT_AH_SendTransferControlByte((char)2, (char)0);
              //stopWatch.Start();

              if (BlockTransferInfinite)
              {
                  EPTTransmitDevice[BlockAddress].Repititions = 1;
              }
              else
              {
                  EPTTransmitDevice[BlockAddress].Repititions--;
              }
              // Allow further transfering
              //EPTTransmitDevice[BlockAddress].TransferPending = false;
          }
      }

      private void btnOk_Click(object sender, EventArgs e)
      {
          EPT_AH_CloseDeviceByIndex(device_index);
          btnOpenDevice.Enabled = true;
          btnCloseDevice.Enabled = false;

          Application.Exit();
      }

      private void btnCancel_Click(object sender, EventArgs e)
      {
          EPT_AH_CloseDeviceByIndex(device_index);
          btnOpenDevice.Enabled = true;
          btnCloseDevice.Enabled = false;

          Application.Exit();

      }


      private unsafe void btnBlinky_Click (object sender, EventArgs e)
      {
         Int32          blink_time = 100;      // 100 milliseconds
         Int32          sequence_cycles = 100; // Cycle, 100 times
         Int32          sequence_size = 24;    // Size of the LED lightshow sequence


         // DEBUG:
         // Use a random timer instead of 100ms
         Random random = new Random();
         // Go between 50 and 300 milliseconds
         blink_time = random.Next(50, 300);

         // Set up light controls according to the following legend:
         // 1: Light 1 ON
         // 2: Light 2 ON
         // 3: Light 3 ON
         // 4: Light 4 ON
         // 0: All lights OFF
         // > 4: Random light ON
         byte[]         light_controls = new byte[24] {1, 0, 2, 0, 3, 0, 4, 0, 
                                                       3, 0, 2, 0, 1, 0, 5, 0, 
                                                       5, 0, 5, 0, 1, 4, 2, 3};
         fixed (byte* pBuf = light_controls)
            {
            // Execute the light show
            EPT_AH_LEDBlinky(blink_time, sequence_cycles, pBuf, sequence_size);
            }
      }

      private void btnResetBlock_Click(object sender, EventArgs e)
      {
          tbBlockRcv.Clear();
      }

      private void EPTParseReceive()
      {
          switch (EPTReceiveData.Command)
          {
              case TRIGGER_OUT_COMMAND:
                  TriggerOutReceive();
                  break;
              case TRANSFER_OUT_COMMAND:
                  TransferOutReceive();
                  break;
              case BLOCK_OUT_COMMAND:
                  BLockOutReceive();
                  break;
              default:
                  break;
          }
      }

      public void TriggerOutReceive()
      {
          switch (EPTReceiveData.Payload)
          {
              case 0x01:
                  lLabelSwitch1.Text = "Switch 1\n Pressed";
                  break;
              case 0x02:
                  lLabelSwitch2.Text = "Switch 2\n Pressed";
                  break;
              case 0x04:
                  lLabelSwitch1.Text = "";
                  lLabelSwitch2.Text = "";
                  break;
          }
      }

      public void TransferOutReceive()
      {
          string WriteRcvChar = "";
          WriteRcvChar = String.Format("{0}", (int)EPTReceiveData.Payload);
          tbDataBytes.AppendText(WriteRcvChar + ' ');
          tbAddress.Text = String.Format("{0:x2}", (uint)System.Convert.ToUInt32(EPTReceiveData.Address.ToString()));
      }

      private void btnTransferReset_Click(object sender, EventArgs e)
      {
          tbDataBytes.Clear();
      }

      public void BLockOutReceive()
      {
          EPTTransmitDevice[EPTReceiveData.Address].TransferPending = false;
          BlockCount = BlockCount + EPTReceiveData.Length;
          BlockErrorCount += ByteArrayCompare(block_in_payload , EPTReceiveData.cBlockBuf, EnableLogFile);

          Thread.Sleep(5);
          Thread t = new Thread(new ParameterizedThreadStart(BlockCompare));
          t.Start(EPTReceiveData.Address);

          if (EPTTransmitDevice[EPTReceiveData.Address].Repititions == 0)
          {
              Thread u = new Thread(new ParameterizedThreadStart(DisplayBlockOut));
              u.Start(BlockCount);
          }
          else if (BlockTransferInfinite)
          {
              if ((LoopCount++ % 100) == 0)
              {
                  Thread u = new Thread(new ParameterizedThreadStart(DisplayBlockOut));
                  u.Start(BlockCount);
              }
          }
      }

      public void DisplayBlockOut(object CountData)
      {
          string s = String.Empty;
          foreach (byte b in EPTReceiveData.cBlockBuf)
          {
              s += String.Format("{0:x2}", (int)System.Convert.ToUInt32(b.ToString()));
              s += "\r\n";
          }
          //tbBlockRcv.AppendText(s);
          this.Invoke(new MethodInvoker(delegate() { tbBlockRcv.AppendText(s); }));

          string s2 = String.Empty;
          s2 = String.Format("{0:x2}", (int)System.Convert.ToUInt32(EPTReceiveData.Address.ToString()));
          this.Invoke(new MethodInvoker(delegate() { tbBlockRcvAddress.Text = s2; }));

          string s3 = String.Empty;
          s3 = String.Format("{0}", (int)EPTReceiveData.Length);
          this.Invoke(new MethodInvoker(delegate() { tbBlockRcvLength.Text = s3; }));

          string sBlockCount = String.Format("{0}", (int)CountData);
          this.Invoke(new MethodInvoker(delegate() { tbBlockCount.Text = sBlockCount; }));


          string sBlockErrorCount = String.Format("{0}", BlockErrorCount);
          this.Invoke(new MethodInvoker(delegate() { tbBlockThruPut.Text = sBlockErrorCount; }));

      }

      public void UpdateTextBlock()
      {
          string s = String.Empty;
          foreach (byte b in EPTReceiveData.cBlockBuf)
          {
              s += String.Format("{0:x2}", (int)System.Convert.ToUInt32(b.ToString()));
              s += "\r\n";
          }
          tbBlockRcv.AppendText(s);
      }

      public int ByteArrayCompare(byte[] a1, byte[] a2, bool EnableLogFile)
      {
          int ErrorCount=0;
          //if (a1.Length != a2.Length)
          //    ErrorCount;

          for (int i = 0; i < a1.Length; i++)
          {
              if (a1[i] != a2[i])
              {
                  ErrorCount++;
                  //if (EnableLogFile)
                  //    ;//Write to Log File
              }
          }

          return ErrorCount;
      }

      private void btnBlockSendRst_Click(object sender, EventArgs e)
      {
          tbBlockSend.Clear();
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

