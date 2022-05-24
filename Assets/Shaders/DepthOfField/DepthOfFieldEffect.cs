using UnityEngine;
using System;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class DepthOfFieldEffect : MonoBehaviour
{

	public Shader dofShader;
	[Range(0.1f, 100f)]
	public float focusDistance = 10f;
	[Range(0.1f, 10f)]
	public float focusRange = 3f;

	private Material dofMaterial;

	const int circleOfConfusionPass = 0;

	void OnRenderImage(RenderTexture source, RenderTexture destination)
	{
		if (dofMaterial == null)
		{
			dofMaterial = new Material(dofShader);
			dofMaterial.hideFlags = HideFlags.HideAndDontSave;
		}

		dofMaterial.SetFloat("_FocusDistance", focusDistance);
		dofMaterial.SetFloat("_FocusRange", focusRange);

		Graphics.Blit(source, destination, dofMaterial, circleOfConfusionPass);
	}
}