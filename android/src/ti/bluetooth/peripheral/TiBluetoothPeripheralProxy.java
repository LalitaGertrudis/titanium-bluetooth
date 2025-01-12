package ti.bluetooth.peripheral;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.le.ScanRecord;
import android.content.Context;
import android.os.ParcelUuid;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.appcelerator.kroll.KrollDict;
import org.appcelerator.kroll.KrollProxy;
import org.appcelerator.kroll.annotations.Kroll;
import org.appcelerator.kroll.common.Log;
import org.appcelerator.titanium.TiBlob;
import ti.bluetooth.TiBluetoothModule;
import ti.bluetooth.gatt.TiBluetoothCharacteristicProxy;
import ti.bluetooth.gatt.TiBluetoothServiceProxy;
import ti.bluetooth.listener.OnPeripheralConnectionStateChangedListener;
import android.util.Base64;

@Kroll.proxy(parentModule = TiBluetoothModule.class)
public class TiBluetoothPeripheralProxy extends KrollProxy {
  private static final String DID_DISCOVER_SERVICES = "didDiscoverServices";
  private static final String DID_DISCOVER_CHARACTERISTICS_FOR_SERVICE =
      "didDiscoverCharacteristicsForService";
  private static final String DID_UPDATE_VALUE_FOR_CHARACTERISTIC =
      "didUpdateValueForCharacteristic";
  private static final String DID_WRITE_VALUE_FOR_CHARACTERISTIC =
      "didWriteValueForCharacteristic";
  private static final String DID_READ_VALUE_FOR_CHARACTERISTIC =
      "didReadValueForCharacteristic";
  private static final String SERVICE_KEY = "service";
  private static final String DID_UPDATE_VALUE_FOR_CHARACTERISTIC_BYTES = "didUpdateValueForCharacteristicBytes";

  private BluetoothDevice bluetoothDevice;
  private BluetoothGatt bluetoothGatt;
  private List<TiBluetoothServiceProxy> services;
  private ScanRecord scanRecord;

  public TiBluetoothPeripheralProxy(BluetoothDevice bluetoothDevice,
                                    ScanRecord scanRecord) {
    this.bluetoothDevice = bluetoothDevice;
    this.scanRecord = scanRecord;
  }

  public void
  connectPeripheral(Context context, final boolean notifyOnConnection,
                    final boolean notifyOnDisconnection,
                    final OnPeripheralConnectionStateChangedListener
                        onPeripheralConnectionStateChangedListener) {
      
      

      bluetoothDevice.connectGatt(context, false, new BluetoothGattCallback() {
      @Override
      public void onConnectionStateChange(BluetoothGatt gatt, int status,
                                          int newState) {
        super.onConnectionStateChange(gatt, status, newState);

        if (status == BluetoothGatt.GATT_SUCCESS) {
          if (newState == BluetoothProfile.STATE_CONNECTED) {
            bluetoothGatt = gatt;
            if (notifyOnConnection) {
              onPeripheralConnectionStateChangedListener
                  .onPeripheralConnectionStateConnected(
                      TiBluetoothPeripheralProxy.this);
            }
          } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
            if (bluetoothGatt != null) {
              disconnectPeripheral();
            }

            if (notifyOnDisconnection) {
              onPeripheralConnectionStateChangedListener
                  .onPeripheralConnectionStateDisconnected(
                      TiBluetoothPeripheralProxy.this);
            } 
          }
        } else {
          if (bluetoothGatt != null) {
            disconnectPeripheral();
          }
          onPeripheralConnectionStateChangedListener
              .onPeripheralConnectionStateError(
                  TiBluetoothPeripheralProxy.this);
        }
      }

      @Override
      public void onServicesDiscovered(BluetoothGatt gatt, int status) {
        super.onServicesDiscovered(gatt, status);

        services = mapServices(gatt.getServices());
        bluetoothGatt = gatt;

        firePeripheralEvent(DID_DISCOVER_SERVICES,
                            TiBluetoothPeripheralProxy.this, null, null);
      }

      @Override
      public void onCharacteristicWrite(
          BluetoothGatt gatt, BluetoothGattCharacteristic characteristic,
          int status) {
        super.onCharacteristicWrite(gatt, characteristic, status);

        firePeripheralEvent(DID_WRITE_VALUE_FOR_CHARACTERISTIC,
                            TiBluetoothPeripheralProxy.this, null,
                            new TiBluetoothCharacteristicProxy(characteristic));
      }

      @Override
      public void onCharacteristicRead(
          BluetoothGatt gatt, BluetoothGattCharacteristic characteristic,
          int status) {
        super.onCharacteristicRead(gatt, characteristic, status);

        firePeripheralEvent(DID_READ_VALUE_FOR_CHARACTERISTIC,
                            TiBluetoothPeripheralProxy.this, null,
                            new TiBluetoothCharacteristicProxy(characteristic));


          final byte[] data = characteristic.getValue();
          if (data != null && data.length > 0) {
              final StringBuilder stringBuilder = new StringBuilder(data.length);
              for(byte byteChar : data) {
                stringBuilder.append(String.format("%02X", byteChar));
              }

              Log.d("onCharacteristicRead", stringBuilder.toString());
          }
      }

      @Override
      public void onCharacteristicChanged(
          BluetoothGatt gatt,
          final BluetoothGattCharacteristic characteristic) {
        super.onCharacteristicChanged(gatt, characteristic);

        firePeripheralEvent(DID_UPDATE_VALUE_FOR_CHARACTERISTIC,
                            TiBluetoothPeripheralProxy.this, null,
                            new TiBluetoothCharacteristicProxy(characteristic));

        final byte[] data = characteristic.getValue();
        if (data != null && data.length > 0) {
            final StringBuilder stringBuilder = new StringBuilder(data.length);
            for(byte byteChar : data) {
              stringBuilder.append(String.format("%02X", byteChar));
            }

            KrollDict kd = new KrollDict();
            kd.put("bytes", stringBuilder.toString());
            Log.d("onCharacteristicChanged", stringBuilder.toString());
            fireEvent(DID_UPDATE_VALUE_FOR_CHARACTERISTIC_BYTES, kd);
        }
      }
    });
  }

  public void disconnectPeripheral() {
    bluetoothGatt.disconnect();
    bluetoothGatt.close();
  }

  private List<TiBluetoothServiceProxy>
  mapServices(List<BluetoothGattService> services) {
    List<TiBluetoothServiceProxy> tiBluetoothServiceProxies = new ArrayList<>();

    for (BluetoothGattService bluetoothGatt : services) {
      tiBluetoothServiceProxies.add(new TiBluetoothServiceProxy(bluetoothGatt));
    }

    return tiBluetoothServiceProxies;
  }

  private void
  firePeripheralEvent(String event,
                      TiBluetoothPeripheralProxy bluetoothPeripheral,
                      TiBluetoothServiceProxy service,
                      TiBluetoothCharacteristicProxy characteristic) {
    KrollDict kd = new KrollDict();
    kd.put("peripheral", bluetoothPeripheral);
    kd.put("service", service);
    kd.put("characteristic", characteristic);

    fireEvent(event, kd);
  }

  @Kroll.method
  public void discoverServices() {
    bluetoothGatt.discoverServices();
  }

  @Kroll.method
  public void discoverCharacteristicsForService(KrollDict args) {
    TiBluetoothServiceProxy service =
        (TiBluetoothServiceProxy)args.get(SERVICE_KEY);

    if (service.getCharacteristics().length > 0) {
      firePeripheralEvent(DID_DISCOVER_CHARACTERISTICS_FOR_SERVICE, this,
                          service, null);
    }
  }

  @Kroll.getProperty
  @Kroll.method
  public String getName() {
    return bluetoothDevice.getName();
  }

  @Kroll.getProperty
  @Kroll.method
  public String getAddress() {
    return bluetoothDevice.getAddress();
  }

  @Kroll.getProperty
  @Kroll.method
  public KrollDict getUuids() {
    ParcelUuid[] uuids = bluetoothDevice.getUuids();
    KrollDict out = new KrollDict();
    if (uuids != null) {
      for (int i = 0; i < uuids.length; i++) {
        out.put("uuid", uuids[i].toString());
      }
    } else {
      Map<ParcelUuid, byte[]> data = scanRecord.getServiceData();
      for (ParcelUuid key : data.keySet()) {
        out.put("uuid", key.toString());
      }
    }
    return out;
  }

  @Kroll.getProperty
  @Kroll.method
  public Object[] getServices() {
    if (services == null) {
      return new Object[0];
    } else {
      return services.toArray();
    }
  }

  @Kroll.method
  public void setNotifyValueForCharacteristic(
      boolean enabled, TiBluetoothCharacteristicProxy characteristic) {
    bluetoothGatt.setCharacteristicNotification(
        characteristic.getCharacteristic(), enabled);
  }


  @Kroll.method
  public void readValueForCharacteristic(TiBluetoothCharacteristicProxy characteristic) {
    bluetoothGatt.readCharacteristic(characteristic.getCharacteristic());
  }

  @Kroll.method
  public void writeValueForCharacteristicWithType(
      TiBlob value,
      TiBluetoothCharacteristicProxy tiBluetoothCharacteristicProxy,
      int writeType) {
    BluetoothGattCharacteristic characteristic =
        tiBluetoothCharacteristicProxy.getCharacteristic();

    characteristic.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
    characteristic.setValue(value.getBytes());
    bluetoothGatt.writeCharacteristic(characteristic);
  }

  @Kroll.method
  public void writeBase64ForCharacteristic(String base64, TiBluetoothCharacteristicProxy tiBluetoothCharacteristicProxy) {
    BluetoothGattCharacteristic characteristic =
        tiBluetoothCharacteristicProxy.getCharacteristic();

    characteristic.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
    characteristic.setValue(Base64.decode(base64, Base64.NO_WRAP));
    bluetoothGatt.writeCharacteristic(characteristic);
  }
}
