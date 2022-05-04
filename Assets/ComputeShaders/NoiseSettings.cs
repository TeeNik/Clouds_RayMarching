using System;
using UnityEngine;


[Serializable]
public class NoiseSettings : ICloneable
{
    public int Resolution;
    public float Coverage;
    public int Octaves;
    public float Frequency;
    public float Lacunarity;
    public float Amplitude;
    public float Persistence;
    public Vector3 Index;

    public object Clone()
    {
        return this.MemberwiseClone() as NoiseSettings;
    }

    public override bool Equals(System.Object obj)
    {
        if ((obj == null) || !this.GetType().Equals(obj.GetType()))
        {
            return false;
        }
        else
        {
            NoiseSettings s = (NoiseSettings)obj;
            return s.Resolution == Resolution
                && s.Coverage == Coverage
                && s.Octaves == Octaves
                && s.Frequency == Frequency
                && s.Lacunarity == Lacunarity
                && s.Amplitude == Amplitude
                && s.Persistence == Persistence
                && s.Index == Index;
        }
    }

    public override int GetHashCode()
    {
        return base.GetHashCode();
    }
}
