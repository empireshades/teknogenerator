/*
|--------------------------------------------|
| TEKNO GENERATOR 3000                       |
|--------------------------------------------|
| By Mathias Bredholt and Mathias Kirkegaard |
| Copyright 2016 - All rights reserved.      |
|                                            |
| Run instruments.scd then generator.scd     |
| and then this.                             |
|--------------------------------------------|
*/

(
// Configuration parameters for the generative algorithm
var res = 64;            // Resolution of the pattern - subdivisions per bar
var num_grains = 2000;   // Number of sound elements to generate for selection
var seq_duration = 4;    // Duration of sequence in bars
var seed = (2**15).rand.round;  // Random seed for reproducible generation
//var seed = 28654;      // Uncommented specific seed
var root, scale, grains, state_rand;

s.latency = 0.2;         // Server latency setting

/*
STATES:
0 - Minimal    // Minimal beats and elements
1 - Build-up   // Increasing complexity and energy
2 - Break      // Breakdown section
3 - Climax     // Peak intensity
*/
thisThread.randSeed = seed;  // Apply random seed to current thread
//6508 - 85 BPM
// 28654 - 85 BPM
// 23376

// Initialize bass synth parameters and controls
~bass_p.set(0 ! 8);      // Reset bass parameters
Synth(\bass_real);       // Create bass synth
~sweep_control = Synth(\sweep_control);  // Create frequency sweep control

// Output seed value for reproducibility
("seed: " + seed).postln;

// Main song generation function
~create_song = {
    var is_playing = true;   // Flag to control playback
    var bar_count = 0;       // Current bar position in pattern
    var state = 0;           // Current musical state (minimal, build-up, etc.)
    var attention_max = 0;   // Maximum attention value for the current section
    
    // Defines maximum attention values for each state - controls density of elements
    var attention_max_in_state = [ 0.75, 1.25, 0.8, 1.5 ] * ~attention_scale;

    // Finite state machine for song structure progression
    var form = Pfsm([
        #[ 3 ],              // Initial state array
        0, #[ 0, 1, 1, 1 ],  // State 0 can go to itself or state 1 (with higher probability)
        1, #[ 1, 2, 2, 2 ],  // State 1 can go to itself or state 2 (with higher probability)
        2, #[ 2, 3, 3, 3 ],  // State 2 can go to itself or state 3 (with higher probability)
        3, #[ 3, 3, 3, 1, 0 ],  // State 3 can go to itself, state 1, or state 0
        nil, nil             // End state (not reached in this case due to inf repetition)
    ], inf).asStream;

    var state_counter = Pseries(0, 1, 10).asStream;  // Counter to track progression through song

    // Create a copy of available instruments and select a subset for use
    var instr_available = ~all_instruments.copy.removeAll([\bd, \hat, \chords]);
    var instr_list = [\bd, \hat, \chords ] ++ ({
        x = instr_available.choose;
        instr_available.remove(x);
        x;
    } ! 7);  // Build a list with required instruments first, then 7 random ones
    
    // Define which instruments are available in each state
    var instr_in_state = {arg i; instr_list[..i+4] } ! 4;
    var bars =  [ 1, 2, 4 ].choose;  // Choose pattern length in bars
    Tempo.bpm = 123.rrand(135);      // Set a random tempo between 123-135 BPM

    // Generate musical material
    root = 55.rrand(66);              // Choose a random root note between 55-66 MIDI
    scale = [ Scale.minor ].choose;   // Use minor scale
    ~init_generation.value;           // Initialize generation parameters
    grains = { ~generate.value(Tempo.bpm, scale, root, res, bars) } ! num_grains;  // Generate grains

    // Initialize patterns for all instruments
    ~all_instruments.do {
        arg instr;
        Pdef((instr ++ "_pat").asSymbol).quant = -1;  // Set quantization to immediate start
        Pdef((instr ++ "_pat").asSymbol).play;        // Start playing the pattern
    };

    // Create a server group for all synths
    g = Group.new(s);

    // Task for controlling filter sweep automation
    Tdef(\sweep_task).quant = -1;
    Tdef(\sweep_task, {
        var old_cutoff = 0;
        // Pattern to generate cutoff frequency modulations
        var cutoff = Pn(Plazy({
            var seq = [[ 0, 0, 0, 0], [ 0, 0, 1, 1 ]].wchoose([0.9, 0.1]);
            var cutoff = seq * ({ 1e3.exprand(10e3) } ! 4);
            Pseq(cutoff);
        })).asStream;
        var lag_time = Pseq([ 0.05, 0, 2, 2 ], inf).asStream;  // Time to transition between values
        loop {
            ~sweep_control.set(\cutoff, cutoff.next, \lag_time, lag_time.next);
            8.wait;  // Wait 8 beats before next change
        };
    }).play;

    // Sidechain compressor trigger pattern
    Pdef(\sidechain).quant = -1;
    Pdef(\sidechain_pat, Pbind(
        \instrument, \sidechain,
        \dur, 1  // Trigger every beat
    )).play;

    // Main song generation routine
    fork {
        while({ is_playing }, {
            var seq = (), median, swing = 0.0.rrand(0.5);  // Initialize sequence and swing amount
            
            // Check if we're starting a new section
            if (bar_count == 0, {
                var count = state_counter.next;
                ("Progress: "++count).postln;

                if (count == nil, {
                    is_playing = false;  // End playback when counter is done
                });
                
                state = form.next;                          // Get next song state
                attention_max = attention_max_in_state[state];  // Set attention limit based on state
                ("State: "++state).postln;
            });

            ("bar "++bar_count).postln;

            // Reduce density in the later bars of each 4-bar section
            if(bar_count > 2, {
                attention_max = attention_max * 0.75;
            });

            "attention".postln;
            attention_max.postln;
            swing = 0.0;  // Reset swing value

            {
                // Create array to track attention at each position in the sequence
                var attention_array = 0 ! (res*bars);
                var ref, k, c;
                
                // Create the discrete time vector (normalized units per step)
                k = (0, 1/res..bars - (1/res));
                
                // Scaling coefficient, 0.5 and 1 for odd and even values of n
                c = Pseq([ 0.5, 1 ], inf).asStream;
                
                // Create discrete reference function using a sinc function
                // This creates a rhythmic template based on multiples of the meter
                ref = (0..(( bars * 4 ) - 1)).sum {
                    arg n;
                    x = ((( 2pi*2*k ) - ((n + (1/2) ) * pi))) * pi;
                    x = x.replace([ 0 ], [ 1e-20 ]);  // Avoid division by zero
                    c.next * ( x.sin / x);  // Sinc function calculation
                };
                
                // Scale and offset the reference function
                ref =  ((ref * attention_max) + (attention_max/2));
                
                // Initialize sequence with default values for all instruments
                ~all_instruments.do {
                    arg instr;
                    // Add all instruments to sequence
                    seq.add(instr -> ());
                    seq[instr].add(\sustained -> false);
                    seq[instr].add(\seq -> ());
                    // Iterate through attributes
                    ~default_attributes[instr].keysValuesDo {
                        arg key, value;
                        // For each attribute add a list of repeated default values
                        seq[instr][\seq].add(key -> (value ! (res * bars)));
                    }
                };

                // Algorithm to select appropriate grains based on attention curve
                grains.do {
                    arg grain;
                    // If the instrument should be in the sequence in the current state
                    if (instr_in_state[state].find([grain[\instrument]]) != nil, {
                        // Copy attention array and add the current grain
                        var tmp = attention_array.copy;
                        var index = grain[\index];
                        tmp[index] = tmp[index] + grain[\attention];
                        
                        // Check if the new attention array follows the reference function
                        // Only add grain if it doesn't exceed the attention threshold
                        if (tmp[index] <= ref[index], {
                            // The grain is added to the sequence
                            attention_array = tmp;
                            grain[\attributes].keysValuesDo {
                                arg key, value;
                                seq[grain[\instrument]][\seq][key][index] = value;
                            };
                        });
                    });
                };
            }.();

            // Create patterns for all instruments in the sequence
            seq.keysValuesDo {
                // key is instrument, attributes is seq
                arg key, attributes;
                var pattern = ();

                // For each instrument attribute create a Pseq containing the sequence of values
                attributes[\seq].keysValuesDo {
                    arg key, value;
                    pattern.add(key->Pseq(value, inf));
                };

                // Create patterns for each instrument and chain them with swingify
                // swingify is a custom pattern to add timing swing
                Pdef((key ++ "_pat").asSymbol, Pchain(~swingify, Pbind(
                    \instrument, key,
                    \group, g,
                    \dur, 4/res,  // Duration based on resolution
                ), Pbind(*pattern.asPairs), (swingBase: 0.5, swingAmount: swing, swingThreshold: 0.1)));
            };
            
            (4*bars).wait;  // Wait for the pattern to complete
            bar_count = (bar_count + 1) % 4;  // Increment bar counter (wrapping at 4)
        });

        // When done playing, free buffers and start a new song
        Buffer.freeAll;
        ~create_song.value;
    };
};

// Start song generation
~create_song.value;

// Master audio processing function
{
    // Read input from global bus
    var chorus_in = In.ar(~chorus, 2);
    // Add delayed versions of input signal with modulated delay times to create chorus effect
    var chorus = chorus_in + Mix(DelayC.ar(chorus_in, 0.2, SinOsc.kr(Rand(0.07, 0.1) ! 2, Rand(0, 2pi) ! 2, 0.009, 0.01), 0) ! 8);

    var master_in = In.ar(0, 2);  // Main audio input
    var delay_in = (chorus * 0.3) + In.ar(~delay, 2);  // Combine chorus and delay inputs
    var reverb_in = (chorus * 0.1) + In.ar(~reverb, 2);  // Combine chorus and reverb inputs

    // Create reverb effect
    var reverb = GVerb.ar(reverb_in[0], 100.rrand(150), 1.rrand(4.0), 0.5, 0.5, 15, drylevel: 0, earlyreflevel: 0.0, taillevel: 1);
    
    // Create delay effect timed to the current tempo
    var delaytime = 60/Tempo.bpm * [4/3, 2/3, 3/2, 1, 5/4, 6/8, 5/6].choose;
    var delay = AllpassC.ar(delay_in, delaytime, delaytime, 2, 0.5);

    // Mix all signals together
    var mix = master_in + delay + chorus + reverb;
    
    // Apply compression to control dynamics
    var compressor = Compander.ar(mix, mix, 0.1, 1, 1/3, 0.02, 0.05) * 10;
    
    // Apply limiting to prevent clipping
    var master_out =  Limiter.ar(compressor, 0.97, 0.02);
    
    // Output the final mix
    ReplaceOut.ar(0, master_out);
}.play(g, addAction: \addToTail);  // Add this processing at the end of the signal chain
)