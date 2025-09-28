
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class SetSliderToMaterial : UdonSharpBehaviour
{
    [SerializeField]
    private MeshRenderer targetRenderer;
    [SerializeField]
    private string propertyName = "_SomeFloat";
    [SerializeField]
    private UnityEngine.UI.Slider _slider;
    [UdonSynced(UdonSyncMode.Linear), FieldChangeCallback(nameof(SliderValue))]
    private float _sliderValue = 0f;
    public float SliderValue
    {
        get => _sliderValue;
        set
        {
            _slider.value = value;
            if (targetRenderer != null)
            {
                targetRenderer.material.SetFloat(propertyName, value);
            }
        }
    }

    private void Start()
    {
        SetValue();
    }

    public void SetValue()
    {
        SliderValue = _slider != null ? _slider.value : 0f;
    }

    public void ChangeOwner()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
    }
}
