
The Python script finds the most closely related sequence in the "focal alignment" with respect to the "alignment" argument.
I have modified the code so it will save the distance matrix (variable d in the script) as well.
I have also added an argument that specifies the output file name for matrix d (it saves as a text file), I only did that so submitting job arrays would be easier, other than that, it does nothing differently

An example of how to run:

python get_distance_to_focal_set_dsave.py --alignment msa_aligned.fasta --reference ref.fasta --focal-alignment focal.fasta --output test_out.fasta --name "d_matrix.txt"


this command does the following: for every sequence in msa_aligned.fasta finds the most closely related sequence in focal.fasta and saves the entire proximity matrix.
Note that the full matrix file is very very large.
