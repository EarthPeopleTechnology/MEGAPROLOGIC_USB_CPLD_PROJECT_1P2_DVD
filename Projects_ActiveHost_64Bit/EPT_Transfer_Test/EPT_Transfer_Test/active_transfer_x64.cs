using System;
using System.Drawing;
using System.Collections.Generic;
using System.Windows.Forms;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading;
using System.Collections;
using System.Runtime.InteropServices;
using System.Diagnostics;


namespace EPT_Transfer_Test 
{
    public partial class EPT_Transfer_Test 
    {
        const string activehost_dll = "ActiveHost64.dll";
        [DllImport(activehost_dll)]
        static extern char EPT_AH_GetName();
        [DllImport(activehost_dll)]
        static extern char EPT_AH_GetVersionString();
        [DllImport(activehost_dll)]
        static extern unsafe void EPT_AH_GetVersionControl(short* v_major, short* v_minor, short* v_revision, short* v_debug);
        [DllImport(activehost_dll)]
        static extern unsafe char EPT_AH_GetInterfaceVersion();
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_CheckCompatibility(char* version, char* interface_version);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_Open(void* in_display_function, void* in_progress_bar_range_function, void* in_progress_bar_value_function);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_Close();
        [DllImport(activehost_dll)]
        static extern unsafe bool EPT_AH_Initialize();
        [DllImport(activehost_dll)]
        static extern unsafe void EPT_AH_Release();
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_QueryDevices();
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_SelectActiveDeviceByName(char* device_name);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_SelectActiveDeviceByIndex(Int32 device_index);
        [DllImport(activehost_dll)]
        static extern unsafe char* EPT_AH_GetDeviceName(int device_index);
        [DllImport(activehost_dll)]
        static extern unsafe char* EPT_AH_GetDeviceSerial(Int32 device_index);
        [DllImport(activehost_dll)]
        static extern unsafe int EPT_AH_OpenDeviceByIndex(Int32 device_index);
        [DllImport(activehost_dll)]
        static extern unsafe int EPT_AH_OpenDeviceByName(char* name);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_CloseDeviceByIndex(int device_index);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_CloseDeviceByName(char* name);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_SendTrigger(byte trigger_value);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_SendByte(Int32 device_channel, char data_byte);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_SendBlock(Int32 device_channel, void* data, UInt32 data_size);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_SendTransferControlByte(char address_to_device, char payload);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_RegisterReadCallback(IntPtr read_callback);
        [DllImport(activehost_dll)]
        static extern unsafe char* EPT_AH_GetLastError();
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_PerformSelfTest();
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_LEDBlinky(Int32 milliseconds, Int32 count, byte* sequence, Int32 sequence_size);
        [DllImport(activehost_dll)]
        static extern unsafe Int32 EPT_AH_SetDebugMode(Int32 debug_mode);

        //Parameters
      public byte COMMAND_DECODE = 0x38;

      //Start of Class Methods
      [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
      unsafe delegate void MyEPTReadFunction(Int32 device_id, Int32 device_channel, byte command, byte payload, byte* data, byte data_size);
      MyEPTReadFunction MyEPTReadFunctionPTR;

      
        // Actual callback function which will read messages coming from the EPT device
        unsafe void EPTReadFunction(Int32 device_id, Int32 device_channel, byte command, byte payload, byte* data, byte data_size)
        {
            byte* message = data;

            // Select current device
            EPT_AH_SelectActiveDeviceByIndex(device_id);

            //Add command and device_channel to the receive object
            EPTReceiveData.Command = ((command & COMMAND_DECODE) >> 3);
            EPTReceiveData.Address = device_channel;

            //Check if the command is Block Receive. If so,
            //use Marshalling to copy the buffer into the receive
            //object
            if (EPTReceiveData.Command == BLOCK_OUT_COMMAND)
            {
                EPTReceiveData.Length = data_size;
                EPTReceiveData.cBlockBuf = new Byte[data_size];

                Marshal.Copy(new IntPtr(message), EPTReceiveData.cBlockBuf, 0, data_size);
            }
            else
            {
                EPTReceiveData.Payload = payload;
            }
            EPTParseReceive();
        }

        // **************** START OF CALLBACK REGISTRATION CODE *****************
        // Register the callback function
        // Declare pointer type of the callback function
        unsafe Int32 RegisterCallBack()
        {
            // Function declaration pointer (includes parameters so C++ knows what to send this function)
            // Grab the C# pointer to the local function: EPTReadFunction
            MyEPTReadFunctionPTR = new MyEPTReadFunction(EPTReadFunction);
            // Grab the actual C++ translation of the pointer of the function:
            IntPtr FctPtr = Marshal.GetFunctionPointerForDelegate(MyEPTReadFunctionPTR);

            // Sent the C++ translation
            if (EPT_AH_RegisterReadCallback(FctPtr) == 0)
            {
                String message = "Error registering callback function: " + Marshal.PtrToStringAnsi((IntPtr)EPT_AH_GetLastError());
                MessageBox.Show(message);
                return 0;
            }

            // Return success
            return 1;
        }
        // **************** END OF CALLBACK REGISTRATION CODE *******************
    }
}
