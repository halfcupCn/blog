hexo g
cp public/ .deploy/halfcupCn.github.io -Force
cd .deploy/halfcupCn.github.io
git add .
git commit -m “new post”
git push origin master