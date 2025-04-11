(
// Wait for the server to boot before proceeding
s.waitForBoot({
    // Define bus numbers for effects
    ~sidechain = 20;  // Bus for sidechain compression effect
    ~reverb = 22;     // Bus for reverb effect
    ~delay = 24;      // Bus for delay effect
    ~chorus = 26;     // Bus for chorus effect
    
    // Control bus for bass parameters (8 channels)
    ~bass_p = Bus.control(s, 8) ; // amp, freq, rez, filter_release, cutoff, distort, reverb, gate
    
    // Control bus for filter sweep effect
    ~sweep = Bus.control.set(0);

    // SIDECHAIN COMPRESSOR TRIGGER
    // This generates a pulse that triggers the sidechain compressor
    SynthDef(\sidechain, {
        // Output a pulse signal to the sidechain bus
        ReplaceOut.ar(~sidechain, Ringz.ar(Impulse.ar((4*60)/127), 50, 0.4) ! 2);
        // Free synth after 0.4 seconds
        Line.kr(dur: 0.4,doneAction: 2);
    }).add;

    // 909 STYLE HI-HAT (SAMPLE-BASED)
    SynthDef(\hat909, {
        arg amp = 0.1, attack = 0.01, sustain_time = 1, distort = 0, bufnum, rate = 1;
        var sig, aEnv;
        // Create amplitude envelope
        aEnv = EnvGen.kr(Env.linen(attack, sustain_time, 0.05 ,curve: -4),doneAction: 2);
        // Play sample with rate variation
        sig = PlayBuf.ar(1,bufnum,rate * BufRateScale.kr(bufnum)) * aEnv * amp;
        // Apply distortion
        sig = (sig * (1-distort)) + ((sig * distort.linexp(0, 1, 1, 100)).distort * distort.linexp(0, 1, 1, 0.01)) * 0.2;
        // Boost high frequencies
        sig = BPeakEQ.ar(sig, 8000, 2, 15);
        // Output to main bus
        Out.ar(0,sig ! 2)
    }).add;

    // 909 STYLE CLAP (SAMPLE-BASED)
    SynthDef(\clap909, {
        arg amp = 0.1, attack = 0.01, sustain_time = 1, distort = 0, bufnum, rate = 1;
        var sig, aEnv;
        // Create amplitude envelope
        aEnv = EnvGen.kr(Env.linen(attack, sustain_time, 0.05 ,curve: -4),doneAction: 2);
        // Play sample with rate variation
        sig = PlayBuf.ar(1,bufnum,rate * BufRateScale.kr(bufnum)) * aEnv * amp;
        // Apply distortion
        sig = (sig * (1-distort)) + ((sig * distort.linexp(0, 1, 1, 100)).distort * distort.linexp(0, 1, 1, 0.01)) * 0.1;
        // Boost high frequencies
        sig = BPeakEQ.ar(sig, 8000, 2, 15);
        // Output to main bus
        Out.ar(0,sig ! 2)
    }).add;

    // BASS DRUM
    SynthDef(\bd, {
        arg amp = 1, freq = 50, sustain_time = 0, release = 1, distort = 0;
        // Create amplitude envelope
        var aEnv = EnvGen.kr(Env([0, 1, 1, 0], [1e-3, sustain_time, 0.1], -4), doneAction: 2);
        // Create resonating pulse
        var sig = Ringz.ar(Impulse.ar(0.1), freq, release) * 0.1 * amp * aEnv;
        // Apply distortion
        sig = (sig * (1-distort)) + ((sig * distort.linexp(0, 1, 1, 100)).distort * distort.linexp(0, 1, 1, 0.01)) * aEnv * 0.5;
        // Apply high-pass filter with sweep modulation
        sig = HPF.ar(sig, 20 + Lag2.kr(In.kr(~sweep), 0.1));
        // Output to main bus
        Out.ar(0, sig ! 2);
    }).add;

    // SNARE DRUM
    SynthDef(\sd, {
        arg amp = 0.1, release = 0.02, reverb = 0.1;
        // Create amplitude envelope
        var aEnv = EnvGen.kr(Env.perc(1e-3, release), doneAction: 2);
        // Mix white noise and sine tone for snare sound
        var sig = WhiteNoise.ar * aEnv * 0.2 * amp;
        sig = sig + (SinOsc.ar(300, 0, 0.3) * aEnv);
        sig = sig * 0.5;
        // Add slight delay for stereo width
        sig = sig + DelayC.ar(sig, 0.05, 0.05, 0.5);
        // Output to main bus
        Out.ar(0, sig * 0.1 ! 2);
        // Commented out reverb send
        // Out.ar(~reverb, sig * reverb ! 2);
    }).add;

    // CLAP SOUND
    SynthDef(\clap, {
        arg amp = 1, release = 0.1, reverb = 0.5, lfo = 50, cutoff = 1e3, distort = 0.5;
        // Create amplitude envelope
        var aEnv = EnvGen.kr(Env.perc(1e-3, release), doneAction: 2);
        // Create secondary envelope modulated by LFO for realistic clap pattern
        var aEnv2 = LFPulse.kr(lfo).range(0,1) * EnvGen.kr(Env.linen(1e-3, 0.02 + (release * 0.15), 0, 1));
        // Mix band-passed noise with different frequencies for a layered clap sound
        var sig = Mix(BBandPass.ar([ WhiteNoise.ar * aEnv2, WhiteNoise.ar * 0.1 * aEnv ], [cutoff, 8e3], 4)) * 0.05 * amp;
        // Add slight delay for stereo width
        sig = [sig, DelayC.ar(sig, 0.0007, 0.0007)];
        // Apply distortion
        sig = (sig * (1-distort)) + ((sig * distort.linexp(0, 1, 1, 100)).distort * distort.linexp(0, 1, 1, 0.15));
        // Output to main bus and reverb
        Out.ar(0, sig * 0.25);
        Out.ar(~reverb, sig * reverb);
    }).add;

    // HI-HAT SOUND
    SynthDef(\hat,{
        arg amp = 0.1, attack = 1e-3, release = 0.1, cutoff = 1000, reverb = 1;
        // Create metallic tone with frequency modulation
        var sig = SinOsc.ar(5e3 + LFTri.ar(5e3, 0, 5e3 * 15));
        // Create amplitude envelope
        var aEnv = EnvGen.kr(Env.perc(attack, release, 1, -6), doneAction: 2);
        // Mix with white noise and apply envelope
        sig = (WhiteNoise.ar + sig) * aEnv * 0.04 * amp;
        // Apply high-pass filter
        sig = HPF.ar(sig, cutoff);
        // Add slight delay for stereo width
        sig = [sig, DelayC.ar(sig, 0.002, 0.002)];
        // Output to main bus and reverb
        Out.ar(0, sig);
        Out.ar(~reverb, sig * reverb);
    }).add;

    // SPECTRAL NOISE - TEXTURAL SOUND
    SynthDef(\spectral_noise, {
        arg amp = 0.2, cutoff = 500, rez = 0.5, phase = 0, teeth = 40;
        // Create amplitude envelope
        var ampEnv = EnvGen.kr(Env.linen(0.15, 0, 0.03 ,1, -4), doneAction: 2);
        // Band-pass filtered gray noise - more musical than white noise
        var sig = BPF.ar(GrayNoise.ar * amp, cutoff + (In.kr(~sweep) * 2), 0.4);
        // Transform to frequency domain, apply comb filter, and transform back to time
        // This creates spectral patterns in the noise
        sig = IFFT(PV_RectComb(FFT(LocalBuf(2048), sig), teeth, phase, 0.05));
        // Increase amplitude with sweep control input
        sig = sig * ampEnv * LinLin.kr(In.kr(~sweep), 0, 5e3, 0.15, 0.6);
        // Output to main bus and reverb
        Out.ar(0, sig ! 2);
        Out.ar(~reverb, sig ! 2);
    }).add;

    // TONE SYNTH - BASIC SYNTH SOUND
    SynthDef(\tone, {
        arg amp = 0.1, attack = 0.01, release = 0.5, freq = 220, dist = 10, chorus = 0, rate = 10;
        // Create amplitude envelope
        var aEnv = EnvGen.kr(Env.perc(attack, release),doneAction: 2);
        // Create frequency modulation for chorus effect
        var freq_mod = (SinOsc.kr(rate,0,chorus)- chorus/2)*100;
        // Generate stereo detuned saw waves
        var sig = Saw.ar([freq*1.01+freq_mod,freq*0.99+freq_mod]);
        // Apply band-pass filter around fundamental frequency
        sig = BPF.ar(sig,freq,0.5) *amp * aEnv;

        /* ---------Effects-------------- */
        // Apply distortion with soft clipping
        sig = (dist) * sig / (1 + (dist * sig.abs));

        // Output to main bus
        Out.ar(0,sig);
    }).add;

    // MEMBRANE PERCUSSION - TUNED PERCUSSION SOUND
    SynthDef(\membrane, {
        arg amp = 0.05, attack = 0.03, release = 0.5, freq = 600, delay = 0.1, reverb = 0.2;
        // Define harmonic ratios for modal synthesis
        var harms = [ 0.56, 0.92, 1.19, 1.71, 2, 2.74, 3, 3.76, 4.07 ];
        // Create amplitude envelope
        var ampEnv = EnvGen.kr(Env.perc(attack, release), doneAction: 2);

        // Create base tone with slight pitch variation
        var sig = SinOsc.ar(freq + LFNoise2.kr(10, 5));
        // Add overtones with dynamic envelopes based on Klang (bank of sine oscillators)
        sig = sig + DynKlang.ar(`[
            harms,  // Frequency ratios
            harms.size.collect {  // Amplitudes with per-partial envelopes
                arg i;
                (2**(i-1).neg) * EnvGen.kr(Env.perc(attack/i, release/(i+1), curve: \sine));
            },
            Rand(0, 2pi)  // Random phase offsets
        ], freq);

        // Add allpass delay for resonance
        sig = sig + AllpassC.ar(sig, delay, delay, 2, 0.2);
        // Add amplitude envelope and noise attack transient
        sig = sig * amp * ampEnv + (
            BPF.ar(WhiteNoise.ar, 2e3, 1, 0.1) * EnvGen.kr(Env.perc(0.01, 0.05))
        );
        // Cut low end with EQ
        sig = BPeakEQ.ar(sig, 100, 1, -10);
        // Attenuate overall level
        sig = sig * 0.1;
        // Output to reverb and main bus
        Out.ar(~reverb, sig * reverb ! 2);
        Out.ar(0,sig ! 2);
    }).add;

    // CYMBAL SOUND - COMPLEX METALLIC SOUND
    SynthDef(\cymbal, {
        // Cymbal sound made with resonatorbanks of fixed exponentially distributed frequencies
        arg release = 10, amp = 1;
        var lodriver, locutoffenv, hidriver, hicutoffenv, freqs, sig;

        // Short impact excitation using bank of resonators
        var ampEnv = EnvGen.ar(Env.perc(0.005,0.1));
        var freqEnv = EnvGen.ar(Env.perc(0.1,0.4))*15e3;
        var excitation = Klank.ar(`[{exprand(300, 20000)}.dup(100), nil, { 0.3 }.dup(100)], Impulse.ar(0.1)) * 1/100;
        excitation = BLowPass4.ar(excitation ,freqEnv+500, 0.4)*ampEnv;

        // Driver for low frequencies to filterbank
        locutoffenv = EnvGen.ar(Env.perc(0.5, release)) * 20000 + 100;
        lodriver = LPF.ar(WhiteNoise.ar(0.1), locutoffenv);

        // Driver for high frequencies to filterbank + amplitude attenuation
        hicutoffenv = XLine.kr(50,4e3, 0.2);
        hidriver = BHiPass4.ar(WhiteNoise.ar(0.1), hicutoffenv, 2);
        hidriver = hidriver * EnvGen.ar(Env.perc(1, 2, release/10)) * 3;

        // Exponential frequency distribution for 200 resonators
        freqs  = {exprand(300, 20000)}.dup(200);
        sig = Klank.ar(`[freqs, nil, { 2 }.dup(200)], lodriver + hidriver + excitation) * 1/200;

        // Mix hit, drivers, and apply envelope
        sig = ((sig * 1) + (lodriver * 2) + (excitation * 2)).dup;
        sig = sig *EnvGen.ar(Env.perc(1e-3, release, 1, -64), doneAction: 2);
        
        // Output to main bus and reverb with distortion for brightness
        Out.ar(0, (sig * 100).distort*0.01*amp ! 2);
        Out.ar(~reverb, (sig * 100).distort*0.2*amp ! 2);
    }).add;

    // RIDE CYMBAL
    SynthDef(\ride,{
        arg release = 1, amp = 0.5;
        // Create amplitude envelope
        var ampEnv = EnvGen.ar(Env.perc(0.005,release, 1, -8),doneAction: 2);
        // Create frequency envelope for filter
        var freqEnv = EnvGen.ar(Env.perc(0.1,release*0.8))*20000;
        // Create resonator bank for metallic sound
        var sig = Klank.ar(`[{exprand(500, 20000)}.dup(100), nil, { release }.dup(100)], Impulse.ar(0.1)) * 1/100;
        // Apply low-pass filter with envelope
        sig = LPF.ar(sig,freqEnv+500);
        // Apply amplitude envelope and attenuation
        sig = sig * ampEnv;
        sig = sig * 0.4;
        // Output to main bus and reverb
        Out.ar(0, sig * 0.1 * amp ! 2);
        Out.ar(~reverb, sig * 0.5 * amp ! 2);
    }).add;

    // BASS SYNTHESIZER - REAL-TIME VERSION
    // This is the actual sound-producing synth for bass
    SynthDef(\bass_real, {
        // Read parameters from control bus
        var p = In.kr(~bass_p, 8);
        var amp = p[0],
        freq = p[1],
        rez = p[2],
        filter_release = p[3],
        cutoff = p[4],
        distort = p[5],
        reverb = p[6],
        gate = p[7];
        
        // Create amplitude envelope
        var aEnv = EnvGen.kr(Env.adsr(0.05, 0.05, 0.7, 0.05), gate);
        // Create filter envelope with sweep modulation
        var fEnv = EnvGen.kr(Env.adsr(0.05, 0.05, 0.5, 0.05), gate, 1e3 - 0.3e3, 0.3e3 + In.kr(~sweep));
        // Mix sine and saw waves for rich bass sound
        var sig = (SinOsc.ar(Lag.kr(freq, 0.4), 0, 1) + Mix(LFSaw.ar(Lag.kr(freq, 0.4) * Rand(0.99, 1.01) ! 4, Rand(0, 1), 0.3))) * 0.1 * amp;
        // Apply 4-pole low-pass filter with envelope
        sig = BLowPass4.ar(sig, fEnv, 1) * 0.5 * aEnv;

        // Apply sidechain compression
        sig = Compander.ar(sig, InFeedback.ar(~sidechain), 0.1, 1, 1/4, 0.01, 0.2);
        // Output to main bus
        Out.ar(0, sig ! 2);
    }).add;

    // BASS SYNTHESIZER - CONTROL SYNTH
    // This is the control synth that sets parameters for bass_real
    SynthDef(\bass, {
        arg amp, freq, rez, filter_release, cutoff, distort, reverb, gate = 1;
        // Send parameters to control bus
        ReplaceOut.kr(~bass_p, [amp, freq, rez, filter_release, cutoff, distort, reverb, gate]);
        // Free synth when gate is released
        EnvGen.kr(Env.asr(0,1,0), gate, doneAction: 2);
    }).add;

    // CHORD SYNTHESIZER
    SynthDef(\chords, {
        arg freq = 500, amp = 1, sustain_time = 2, cutoff = 100, filter_release = 0.03, reverb = 0.2, delay = 0.6, rez = 0.4;
        // Create amplitude envelope
        var aEnv = EnvGen.kr(Env.new([0, 1, 0.5, 0], [0.01, sustain_time, 0.05], -4), doneAction: 2);
        // Create filter envelope with sweep modulation
        var fEnv = EnvGen.kr(Env.perc(1e-3, filter_release), 1, cutoff - freq, freq + In.kr(~sweep));
        // Randomly choose between saw and pulse waveforms
        var sig = Select.ar(IRand(0, 1), [
            // Detuned stereo saw waves
            LFSaw.ar(
                freq * Rand(0.995, 1.005) ! 2,
                Rand(0, 1),
                0.3
            ),
            // Pulse wave with random width
            LFPulse.ar(
                freq * Rand(0.995, 1.005) ! 2,
                Rand(0, 1),
                Rand(0, 1),
                0.3
            )
        ]) * 0.1 * aEnv * amp;
        // Apply low-pass filter with envelope
        sig = BLowPass.ar(sig, fEnv, 0.3);
        // Output to chorus effect
        Out.ar(~chorus, sig);
    }).add;

    // PAD SYNTHESIZER - SUSTAINED ATMOSPHERIC SOUND
    SynthDef(\pads, {
        arg freq = 500, amp = 1, sustain_time = 2, cutoff = 100, reverb = 0.4, delay = 0.6, rez = 0.4;
        // Create amplitude envelope with longer segments for pads
        var aEnv = EnvGen.kr(Env.new([0, 1, 1, 0], [0.1, sustain_time, 0.1], -4), doneAction: 2);
        // Randomly choose between saw and pulse waveforms
        var sig = Select.ar(IRand(0, 1), [
            // Detuned stereo saw waves
            LFSaw.ar(
                freq * Rand(0.995, 1.005) ! 2,
                Rand(0, 1),
                0.3
            ),
            // Pulse wave with random width
            LFPulse.ar(
                freq * Rand(0.995, 1.005) ! 2,
                Rand(0, 1),
                Rand(0, 1),
                0.3
            )
        ]) * 0.15 * aEnv * amp;
        // Apply low-pass filter with sweep modulation
        sig = BLowPass.ar(sig, 0.3e3 + (In.kr(~sweep) * 1), 0.3);
        // Apply sidechain compression from sidechain input
        sig = Compander.ar(sig, In.ar(~sidechain, 2) * 6, 0.1, 1, 1/4, 0.01, 0.1);
        // Output to chorus effect
        Out.ar(~chorus, sig);
    }).add;

    // FM SYNTHESIS STAB SOUND
    SynthDef(\fm_stab, {
        arg freq = 500, amp = 0.1, attack = 0.1, release = 0.1, detune = 0.5;
        // Create array of modulation frequency partials and modulations indexes
        var partials = [ 1 + detune, 2 + detune, 4 + detune, 12 + detune ];
        var indexes = [ 1, 2, 4, 8 ];
        // Create amplitude envelope
        var ampEnv = EnvGen.ar(Env.perc(attack, release), doneAction: 2);
        // Create frequency envelope for initial pitch bump
        var freqEnv = freq + (EnvGen.ar(Env.perc(0.01, 0.1)) * 4e3);
        // Create carrier oscillator and modulate the frequency with a sum of modulators
        var sig = SinOsc.ar(freq + Mix(partials.size.collect {
            arg n;
            var modfreq = freq * partials[n] * Rand(0.9999, 1.0001) ! 2;
            SinOsc.ar(modfreq, 0, modfreq*indexes[n]);
            // Phase is modulated by a Saw oscillator for additional timbre
        }), Saw.kr(3).range(-2pi, 2pi));
        // Apply envelope and amplitude
        sig = sig * amp * ampEnv * 0.3;
        // Apply band-pass filter to attenuate high frequency content
        sig = BBandPass.ar(sig, freqEnv, 1.5);
        // Output to chorus and main bus
        Out.ar(~chorus, sig * 0.1);
        Out.ar(0, sig * 0.5);
    }).add;

    // BELL SOUND - MODAL SYNTHESIS
    SynthDef(\bell, {
        arg gate=1, freq=100, decay=0.6, amp=1, reverb = 0.05, distort = 1, delay = 0.5;
        var excitation, sig, aEnv, fEnv;
        // Create brief noise burst for attack
        excitation = WhiteNoise.ar(EnvGen.ar(Env.perc(1e-6, 0.01)));
        // Create bank of resonators for bell timbre
        sig = Klank.ar(`[
            // Frequency ratios - carefully tuned for bell sound
            [0.501, 1, 0.7,   2.002, 3, 9.6,   2.49, 11, 2.571,  3.05, 6.242, 12.49, 13, 16, 24],
            // Amplitude for each partial
            [0.002,0.02,0.001, 0.008,0.02,0.004, 0.02,0.04,0.02, 0.005,0.05,0.05, 0.02, 0.03, 0.04],
            // Ring times for different frequency ranges
            [1.2, 0.9, 0.25, 0.14, 0.07].stutter(3)
        ]
        , excitation, freq, 0, decay);
        // Create amplitude envelope
        aEnv = EnvGen.ar(Env.perc(1e-3,decay),doneAction: 2);
        // Mix signal with excitation and apply envelope
        sig = (sig+excitation) * 0.2 * amp;
        // Apply distortion
        sig = (sig * (1-distort)) + ((sig * distort.linexp(0, 1, 1, 100)).distort * distort.linexp(0, 1, 1, 0.02));
        // Output to main bus, reverb, and delay
        Out.ar(0, sig ! 2);
        Out.ar(~reverb, sig*reverb ! 2);
        Out.ar(~delay, sig*delay ! 2);
    }).add;

    // FILTER SWEEP CONTROL
    // This controls the filter sweep effect across multiple instruments
    SynthDef(\sweep_control, {
        arg cutoff = 0, lag_time = 0.5;
        // Send lagged cutoff value to sweep control bus
        Out.kr(~sweep, Lag.kr(cutoff, lag_time));
    }).add;
});
)
