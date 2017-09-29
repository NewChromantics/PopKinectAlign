using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PointCloudMesh : MonoBehaviour {


	public void SetDepthTexture(Texture Depth)
	{
		var mat = GetComponent<MeshRenderer> ().material;
		mat.SetTexture ("DepthTexture", Depth);
	}

	public void SetColourTexture(Texture Colour)
	{
		var mat = GetComponent<MeshRenderer> ().material;
		mat.SetTexture ("ColourTexture", Colour);
	}

}
