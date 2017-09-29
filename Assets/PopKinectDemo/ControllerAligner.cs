using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ControllerAligner : MonoBehaviour {

	[Range(0,10)]
	public int						TrackingControllerIndex = 0;

	[Range(0,50)]
	public int						TrackCircleIndex = 0;

	public PopKinectExtractCircles	Extractor;


	[Range(0,100)]
	public float					MinRadius = 1;
	[Range(0,100)]
	public float					MaxRadius = 1;

	//	this are more than likely not linear.
	[Range(0,3)]
	public float					MinDistance = 0;
	[Range(0,3)]
	public float					MaxDistance = 3;

	public float					ControllerHoleRadius = 0.04f;

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


	void OnDrawGizmos()
	{
		Gizmos.color = Color.yellow;
		Gizmos.matrix = this.Extractor.transform.localToWorldMatrix;

		var Circles = Extractor.GetCirclesInUvSpace ();

		foreach (var Circle in Circles) {
			var Pos = CircleToWorld (Circle);
			Gizmos.DrawWireSphere (Pos, ControllerHoleRadius);
		}
	}

	Vector3 CircleToWorld(Vector4 Circle)
	{
		//	get ray
		var Ray = Extractor.KinectCamera.GetColourRay (Circle);

		//	invert radius so small=far, big=near
		var RadiusNorm = 1 - PopMath.Range (MinRadius, MaxRadius, Circle.z);
		var Distance = Mathf.Lerp (MinDistance, MaxDistance, RadiusNorm);

		//	place camera from our controller along the ray, backwards
		var DeltaFromCamera = Ray.GetPoint (Distance);
		return DeltaFromCamera;
		var CameraPosition = this.transform.localPosition - DeltaFromCamera;
		return CameraPosition;
	}


}
