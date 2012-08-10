template_file=manifests/ubuntu-12.04-template.pp
outputfile=manifests/ubuntu-12.04.pp
echo 'Enter the path to your local repository:'
read path
sed "s@#path#@$path@g" $template_file > $outputfile