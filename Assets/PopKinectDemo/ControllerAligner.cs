using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ControllerAligner : MonoBehaviour {

	[Range(0,10)]
	public int		TrackingControllerIndex = 0;

	public void UpdateController(List<OpenvrControllerFrame> Controllers)
	{
		try
		{
			var Controller = Controllers [TrackingControllerIndex];

			var Active = Controller.Tracking && Controller.Attached;
			this.gameObject.SetActive (Active);

			if (!Active)
				return;

			this.transform.localPosition = Controller.Position;
			this.transform.localRotation = Controller.Rotation;
		}
		catch(System.Exception e) {
			this.gameObject.SetActive (false);
		}
	}



}
