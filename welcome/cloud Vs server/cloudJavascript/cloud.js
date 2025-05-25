// Handling nav bar 
let home =document.getElementById("nav-home");
let services =document.getElementById("nav-services");
let aboutUs =document.getElementById("nav-about-us");
home.onclick = function () {
    window.location.href = "../page.html#home";
}
services.onclick = function () {
    window.location.href = "../page.html#services";
}
aboutUs.onclick = function () {
    window.location.href = "../page.html#about";
}
// Handling the product menu 
let ourProduct = document.getElementById("product");
let productMenu = document.getElementById("product-menu");
ourProduct.onclick = function () {
    productMenu.style.display = "flex";
}
document.addEventListener('click', (event) => {
    if (!ourProduct.contains(event.target) && !productMenu.contains(event.target)) {
        productMenu.style.display = "none";    }
});

