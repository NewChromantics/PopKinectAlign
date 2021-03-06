﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PopKinectExtractCircles : MonoBehaviour {

	public string				DataOutputKeyword = "DATA_OUTPUT";
	public Material				CircleFilter;
	public UnityEvent_Texture	OnDataTextureChanged;
	public Material				CircleMaterial;
	public string				CircleMaterial_CircleArrayUniform = "Circles";
	public int					CircleMaterial_CircleArrayCount = 50;

	[Range(0,10)]
	public int 					RefineIterations = 0;
	public bool					DrawRays = true;
	public PopKinectCamera		KinectCamera;

	RenderTexture				DataRenderTexture;
	RenderTexture				DataRenderTexture_Refined;
	Texture2D					DataTexture2D;
	List<Vector4>				LastCircles;
	Vector2						LastCirclesImageSize;

	public Vector4?				GetBestCircleInUvSpace()
	{
		try
		{
			var Circle = LastCircles[0];
			Circle.x /= LastCirclesImageSize.x;
			Circle.y /= LastCirclesImageSize.y;
			return Circle;
		}
		catch(System.Exception e)
		{
			return null;
		}
	}

	public List<Vector4>			GetCirclesInUvSpace()
	{
		var Circles = new List<Vector4>();

		try
		{
			foreach ( var Circlexy in LastCircles )
			{
				var Circle = Circlexy;
				Circle.x /= LastCirclesImageSize.x;
				Circle.y /= LastCirclesImageSize.y;
				Circles.Add( Circle);
			}
		}
		catch(System.Exception e)
		{
		}
		return Circles;
	}

	public void ExtractCircles(Texture ImageTexture)
	{
		if (DataRenderTexture == null) {
			DataRenderTexture = new RenderTexture (ImageTexture.width, ImageTexture.height, 0, RenderTextureFormat.ARGBFloat);
			DataRenderTexture.filterMode = FilterMode.Point;
		}

		CircleFilter.EnableKeyword (DataOutputKeyword);
		Graphics.Blit (ImageTexture, DataRenderTexture, CircleFilter);

		for (int i = 0;	i < RefineIterations;	i++) {
			if (DataRenderTexture_Refined == null) {
				DataRenderTexture_Refined = new RenderTexture (DataRenderTexture.width, DataRenderTexture.height, 0, DataRenderTexture.format);
				DataRenderTexture_Refined.filterMode = DataRenderTexture.filterMode;
			}
			Graphics.Blit (DataRenderTexture, DataRenderTexture_Refined, CircleFilter);
			Graphics.Blit (DataRenderTexture_Refined, DataRenderTexture);
		}

		CircleFilter.DisableKeyword (DataOutputKeyword);



		SaveTextureToPng.GetTexture2D (DataRenderTexture, ref DataTexture2D, TextureFormat.RGBAFloat);
		OnDataTextureChanged.Invoke (DataTexture2D);

		//	extract circles
		var Pixelsf = DataTexture2D.GetPixels ();
		var Circles = ExtractCircles (Pixelsf,DataTexture2D.width);

		while (Circles.Count < CircleMaterial_CircleArrayCount)
			Circles.Add (Vector4.zero);
		CircleMaterial.SetVectorArray (CircleMaterial_CircleArrayUniform, Circles);
		LastCircles = Circles;
		LastCirclesImageSize = new Vector2 (DataTexture2D.width, DataTexture2D.height);
	}

	List<Vector4> ExtractCircles(Color[] Pixels,int ImageWidth)
	{
		var Circles = new List<Vector4>();
		for ( int i=0;	i<Pixels.Length;	i++ )
		{
			var Score = Pixels [i].g;
			var Radius = Pixels [i].b;
			var x = i % ImageWidth;
			var y = i / ImageWidth;
			AddCircle( Circles, x, y, Radius, Score );

			if (Circles.Count >= CircleMaterial_CircleArrayCount)
				break;
		}

		Circles.Sort ((a, b) => {
			return (a.w > b.w) ? -1 : (a.w == b.w) ? 0 : 1;
		});

		return Circles;
	}

	bool MergeCircle(ref Vector4 Old,Vector4 New)
	{
		Vector2 Old2 = Old;
		Vector2 New2 = New;
		//	merge if they overlap
		var Delta = New2 - Old2;
		var Distance = Delta.magnitude;

		if (Distance > Old.z + New.z)
			return false;

		//	left edge
		Delta.Normalize();
		var Left = Old2 - (Delta * Old.z);
		var Right = New2 + (Delta * New.z);
		var Center = Vector2.Lerp (Left, Right, 0.5f);
		var Radius = (Right - Left).magnitude / 2;
		Old.x = Center.x;
		Old.y = Center.y;
		Old.z = Radius;
		Old.w += New.w;
		return true;
	}

	void AddCircle(List<Vector4> Circles,int x,int y,float Radius,float Score)
	{
		if (Radius <= 0)
			return;
		
		var NewCircle = new Vector4 (x, y, Radius,Score);

		var Merged = false;
		for (int i = 0;	i < Circles.Count;	i++) {
			var OldCircle = Circles [i];
			if (MergeCircle (ref OldCircle, NewCircle))
				Merged = true;
		}

		if (!Merged) {
			Circles.Add (NewCircle);
		}

	}

	void OnDrawGizmos()
	{
		if (!DrawRays)
			return;
		if (!KinectCamera)
			return;
		if (LastCircles == null)
			return;

		Gizmos.color = Color.green;
		Gizmos.matrix = this.transform.localToWorldMatrix;
		foreach (var circle in LastCircles) {
			var u = circle.x / LastCirclesImageSize.x;
			var v = circle.y / LastCirclesImageSize.y;
			var ray = KinectCamera.GetColourRay (new Vector2 (u, v));
			Gizmos.DrawRay (ray);
		}
	}
}
