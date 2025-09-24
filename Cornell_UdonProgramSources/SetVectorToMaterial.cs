
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class SetVectorToMaterial : UdonSharpBehaviour
{
    [SerializeField] MeshRenderer targetRenderer;
    [SerializeField] string propertyName = "_SomeVector";

    private void Update()
    {
        if (targetRenderer != null)
        {
            targetRenderer.material.SetVector(propertyName, transform.position);
        }
    }
}
