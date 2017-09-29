using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Threading;

//[System.Serializable]
//public class UnityEvent_Texture : UnityEngine.Events.UnityEvent <Texture> {}

public class PopKinectCamera : MonoBehaviour {

	class TPendingFrame
	{
		public byte[]	Pixels;
		public int		Width = 0;
		public int 		Height = 0;
		public freenect.VideoFormat?		ColourFormat = null;
		public freenect.DepthFormat?		DepthFormat = null;
		public bool		Dirty = false;

		private void		Update(freenect.BaseDataMap Data)
		{
			if (Pixels == null || Pixels.Length != Data.Data.Length) {
				Pixels = new byte[Data.Data.Length];
			}
			Data.Data.CopyTo (Pixels,0);
			Width = Data.Width;
			Height = Data.Height;
			Dirty = true;
		}

		public void		Update(freenect.BaseDataMap Data,freenect.VideoFormat Format)
		{
			Update(Data);
			ColourFormat = Format;
			DepthFormat = null;
		}

		public void		Update(freenect.BaseDataMap Data,freenect.DepthFormat Format)
		{
			Update(Data);
			ColourFormat = null;
			DepthFormat = Format;
		}


	};

	[Range(0,15)]
	public int	DeviceIndex = 0;


	public bool					EnableMotor = false;
	public bool					EnableAudio = false;
	bool						EnableCamera	{	get{ return EnableColour || EnableDepth; }}

	public bool					EnableColour = true;
	public UnityEvent_Texture	OnColourTextureChanged;
	Texture2D					ColourTexture;
	TPendingFrame				ColourFrame;		//	locked frame updated from kinect thread
	[Range(0,180)]
	public float				ColourFieldOfViewHorizontal = 58.5f;
	[Range(0,180)]
	public float				ColourFieldOfViewVertical = 45.6f;

	public bool					EnableDepth = true;
	public UnityEvent_Texture	OnDepthTextureChanged;
	Texture2D					DepthTexture;
	TPendingFrame				DepthFrame;		//	locked frame updated from kinect thread


	freenect.Kinect				Device;
	Thread						DeviceThread;

	static public TextureFormat GetFormat(freenect.VideoFormat Format)
	{
		switch(Format)
		{
		case freenect.VideoFormat.RGB:
			return TextureFormat.RGB24;

		case freenect.VideoFormat.Infrared8Bit:
			return TextureFormat.R8;

		default:
			throw new System.Exception("Unhandled format " + Format);
		}
	}

	static public TextureFormat GetFormat(freenect.DepthFormat Format)
	{
		switch(Format)
		{
		case freenect.DepthFormat.Depth11Bit:
		case freenect.DepthFormat.Depth10Bit:
		case freenect.DepthFormat.DepthPacked11Bit:
		case freenect.DepthFormat.DepthPacked10Bit:
		case freenect.DepthFormat.DepthRegistered:
		case freenect.DepthFormat.DepthMM:
			return TextureFormat.R16;

		default:
			throw new System.Exception("Unhandled format " + Format);
		}
	}


	void Dealloc()
	{
		var TempDevice = Device;
		Device = null;

		try
		{
			Debug.Log("Aborting thread");
			DeviceThread.Abort();
			Debug.Log("Joining thread");
			DeviceThread.Join();
			DeviceThread = null;
		}
		catch(System.Exception e) 
		{
			Debug.LogException (e);
			DeviceThread = null;
		}

		try
		{
			
			TempDevice.DepthCamera.Stop();
			TempDevice.VideoCamera.Stop();
			Debug.Log("Closing device");
			TempDevice.Close ();
			freenect.Kinect.Shutdown();
			TempDevice = null;
		}
		catch(System.Exception e) 
		{
			Debug.LogException (e);
		}
	}

	void Awake()
	{
		var ctx = freenect.KinectNative.Context;
		freenect.Kinect.LogLevel = freenect.LoggingLevel.Debug;
		freenect.Kinect.Log += (device,logevent) =>{	Debug.Log(logevent.Message);};
	}

	void OnEnable()
	{
		Debug.Log ("Found " + freenect.Kinect.DeviceCount + " devices");
		try
		{
			Device = new freenect.Kinect (DeviceIndex);
			Device.Open( EnableCamera, EnableMotor, EnableAudio );

			//Device.Motor.Tilt = 0;
			Device.LED.Color = freenect.LEDColor.Red;

			// Setup event handlers
			Device.VideoCamera.DataReceived += OnColourFrame;
			Device.DepthCamera.DataReceived += OnDepthFrame;

			Device.DepthCamera.Mode = freenect.DepthFrameMode.Find( freenect.DepthFormat.Depth11Bit, freenect.Resolution.Medium );
			Device.VideoCamera.Mode = freenect.VideoFrameMode.Find( freenect.VideoFormat.RGB, freenect.Resolution.Medium );

			//	gr: added
			//Device.VideoCamera.DataBuffer = System.IntPtr.Zero;
			//Device.DepthCamera.DataBuffer = System.IntPtr.Zero;

			// Start cameras
			Device.DepthCamera.Start();
			Device.VideoCamera.Start();


			// Start update thread
			DeviceThread = new Thread (new ThreadStart (ThreadUpdate));
			DeviceThread.Start ();

			Device.LED.Color = freenect.LEDColor.BlinkGreen;


		}
		catch(System.Exception e) {
			Debug.LogException (e);
			Dealloc ();
			throw;
		}
	}

	void OnDisable()
	{
		Dealloc ();
	}

	void OnColourFrame(object _Camera,freenect.BaseCamera.DataReceivedEventArgs Event)
	{
		var Camera = _Camera as freenect.VideoCamera;

		if ( ColourFrame == null )
			ColourFrame = new TPendingFrame ();

		lock (ColourFrame) {
			ColourFrame.Update (Event.Data, Camera.Mode.Format);
		}
	}

	void OnDepthFrame(object _Camera,freenect.BaseCamera.DataReceivedEventArgs Event)
	{
		var Camera = _Camera as freenect.DepthCamera;

		if ( DepthFrame == null )
			DepthFrame = new TPendingFrame ();

		lock (DepthFrame) {
			DepthFrame.Update (Event.Data, Camera.Mode.Format);
		}
	}

	freenect.VideoCamera GetColourCamera()
	{
		var Camera = Device.VideoCamera;
		try
		{
			if ( EnableColour && !Camera.IsRunning )
			{
				Camera.Start();
				Camera.DataReceived += OnColourFrame;
				Debug.Log("Camera Started");
			}
			else if ( !EnableColour && Camera.IsRunning )
			{
				Camera.DataReceived -= OnColourFrame;
				Camera.Stop();
				Debug.Log("Camera Stopped");
			}
		}
		catch (System.Exception e) {
			Debug.LogException (e);
			Camera.DataReceived -= OnColourFrame;
		}

		return Camera.IsRunning ? Camera : null;
	}


	void ThreadUpdate()
	{
		while ( Device != null ) {
			//Debug.Log ("freenect.Kinect.ProcessEvents ()");
			Device.UpdateStatus();
			freenect.Kinect.ProcessEvents ();
		}
		Debug.Log ("ThreadUpdate finished");
	}


	void UpdateTexture(TPendingFrame Frame,ref Texture2D Texture,UnityEvent_Texture OnChanged)
	{
		if (Frame == null)
			return;
		
		lock(Frame)
		{
			if ( !Frame.Dirty )
				return;

			try
			{
				if ( Texture == null )
				{
					var Format = Frame.ColourFormat.HasValue ? GetFormat(Frame.ColourFormat.Value) : GetFormat(Frame.DepthFormat.Value);
					Texture = new Texture2D( Frame.Width, Frame.Height, Format, false );
				}
					
				Texture.LoadRawTextureData( Frame.Pixels );
				Texture.Apply();
				Frame.Dirty = false;

				OnChanged.Invoke( Texture );
			}
			catch(System.Exception e) {
				Debug.LogException (e);
			}
		}			
	}

	void Update()
	{
		if (Device == null) {
		//	Debug.Log ("Device is null");
			return;
		}

		if (!Device.IsOpen) {
			Debug.Log ("Device is not open");
			return;
		}

		UpdateTexture (ColourFrame, ref ColourTexture, OnColourTextureChanged);
		UpdateTexture (DepthFrame, ref DepthTexture, OnDepthTextureChanged);

			
		/*
		var ColourCamera = GetColourCamera ();
			
		if ( DoUpdateStatus )
			Device.UpdateStatus ();

		if ( DoProcessEvents )
			freenect.Kinect.ProcessEvents ();

		if (DoProcessEventsOnThread) {
			if (DeviceThread != null) {
				DeviceThread = new Thread (new ThreadStart (ThreadUpdate));
				DeviceThread.Start ();
			}
		} else {
			if (DeviceThread != null) {
				DeviceThread.Abort ();
				DeviceThread = null;
			}
		}
*/
	}

	public Ray GetColourRay(Vector2 uv)
	{
		var ray = new Ray (Vector3.zero, Vector3.forward);
		var dir = ray.direction;

		var anglex = (uv.x - 0.5f) * 2.0f;
		var fovhrad = Mathf.Deg2Rad * ( anglex * ColourFieldOfViewHorizontal );
		dir.x = Mathf.Tan (fovhrad);

		var angley = ( (1-uv.y) - 0.5f) * 2.0f;
		var fovvrad = Mathf.Deg2Rad * ( angley * ColourFieldOfViewVertical );
		dir.y = Mathf.Tan (fovvrad);

		ray.direction = dir;
			
		return ray;
	}
}
