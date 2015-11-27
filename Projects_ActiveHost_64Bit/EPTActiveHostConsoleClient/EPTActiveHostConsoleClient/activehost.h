/*
   LIB USB
   Copyright (c) 2012 Earth People Technology. All rights reserved.
   Author(s): Richard J. Jolly, Nawfel Tricha
   Creation Date: 09/01/2012
   Description: USB library interface header

   $Rev$
   $Author$
   $Date$
   $URL$
*/

#ifndef LIB_USB_INTERFACE_H
#define LIB_USB_INTERFACE_H

   extern "C"
      {
      __declspec(dllimport) char *EPT_AH_GetName();
      __declspec(dllimport) char *EPT_AH_GetVersionString();
      __declspec(dllimport) void EPT_AH_GetVersionControl(unsigned short *v_major, unsigned short *v_minor, unsigned short *v_revision, unsigned short *v_debug);
      __declspec(dllimport) char *EPT_AH_GetInterfaceVersion();
      __declspec(dllimport) int EPT_AH_CheckCompatibility(char *version, char *interface_version);
      __declspec(dllimport) int EPT_AH_Open(void *in_display_function, void *in_progress_bar_range_function, void *in_progress_bar_value_function);
      __declspec(dllimport) int EPT_AH_Close();
      __declspec(dllimport) bool EPT_AH_Initialize();
      __declspec(dllimport) void EPT_AH_Release();
      __declspec(dllimport) int EPT_AH_QueryDevices();
      __declspec(dllimport) int EPT_AH_SelectActiveDeviceByName(char *device_name);
      __declspec(dllimport) int EPT_AH_SelectActiveDeviceByIndex(int device_index);
      __declspec(dllimport) char *EPT_AH_GetDeviceName(int device_index);
      __declspec(dllimport) char *EPT_AH_GetDeviceSerial(int device_index);
      __declspec(dllimport) int EPT_AH_OpenDeviceByIndex(int device_index);
      __declspec(dllimport) int EPT_AH_OpenDeviceByName(char *name);
      __declspec(dllimport) int EPT_AH_CloseDeviceByIndex(int device_index);
      __declspec(dllimport) int EPT_AH_CloseDeviceByName(char *name);
      __declspec(dllimport) int EPT_AH_SendTrigger(unsigned char trigger_value);
      __declspec(dllimport) int EPT_AH_SendByte(unsigned long device_channel, unsigned char byte);
      __declspec(dllimport) int EPT_AH_SendBlock(unsigned long device_channel, void *data, unsigned long data_size);
      __declspec(dllimport) int EPT_AH_SendTransferControlByte(unsigned char address_to_device, unsigned char payload);
      __declspec(dllimport) int EPT_AH_RegisterReadCallback(void *read_callback);
      __declspec(dllimport) char *EPT_AH_GetLastError();
      __declspec(dllimport) int EPT_AH_PerformSelfTest(); 
      __declspec(dllimport) int EPT_AH_SetDebugMode(int debug_mode); 
      }

   // Example of a template read callback function
   void TemplateReadCallback(int device_id, int device_channel, unsigned char command, unsigned char payload, unsigned char *data, unsigned char data_size);

#endif

/*
   End of file
*/
