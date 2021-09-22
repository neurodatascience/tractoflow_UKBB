# Sets up fakebids
# run from within container created by tf_shell_symtree.sh
ROOT_BIDS=/dwipipeline/ukbb/imaging
FAKE_BIDS=/fakebids/dwi_subs

counter=0
while read sub1; do
pretty_counter=$(printf "%4.4d" $counter)
 read sub2
 read sub3
 read sub4
 echo "Making $pretty_counter"
 mkdir ${FAKE_BIDS}-$pretty_counter
 echo "Creating symlinks"
 ln -s ${ROOT_BIDS}/$sub1 ${FAKE_BIDS}-$pretty_counter/$sub1
 ln -s ${ROOT_BIDS}/$sub2 ${FAKE_BIDS}-$pretty_counter/$sub2
 ln -s ${ROOT_BIDS}/$sub3 ${FAKE_BIDS}-$pretty_counter/$sub3
 ln -s ${ROOT_BIDS}/$sub4 ${FAKE_BIDS}-$pretty_counter/$sub4
 echo $sub1 >> ${FAKE_BIDS}-$pretty_counter/participants.tsv
 echo $sub2 >> ${FAKE_BIDS}-$pretty_counter/participants.tsv
 echo $sub3 >> ${FAKE_BIDS}-$pretty_counter/participants.tsv
 echo $sub4 >> ${FAKE_BIDS}-$pretty_counter/participants.tsv
 ln -s ${ROOT_BIDS}/dataset_description.json ${FAKE_BIDS}-$pretty_counter/dataset_description.json
 counter=$(( $counter + 1))
echo "Done"
done < ${ROOT_BIDS}/participants.tsv
