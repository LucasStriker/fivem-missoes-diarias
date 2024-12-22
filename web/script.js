window.addEventListener('message', function (event) {
	var item = event.data;
	
	if (item.show) {
		$("body").css("display", "");
		$(document).off("click", ".btn.btn-primary");

		let progressBar = `<div class="progress"><div class="progress-bar" role="progressbar" style="width: 25%" aria-valuenow="25" aria-valuemin="0" aria-valuemax="100"></div></div>`
		$(".table tbody").html(``)
		Object.values(item.data).forEach(v => {
			// Permitir que missões acima da 1 tenham uma progress bar para demonstração
			let progress = v.started ? (v.conclude ? (v.redeemed ? "Finalizada" : "Concluída") : (v.id == 1 ? "Iniciada" : progressBar))  : "Não Iniciada"

			let disabledButton = v.conclude && !v.redeemed || !v.started ? "" : "disabled"

			$(".table tbody").html($(".table tbody").html() + `
				<tr>
					<th scope="row">
						<div class="mt-2">${v.id}</div>
					</th>
					<td>
						<div class="mt-2">${v.name}</div>
					</td>
					<td>
						<div class="mt-2">$ ${v.reward} em dinheiro.</div>
					</td>
					<td>
						<div class="mt-2">${progress}</div>
					</td>
					<td>
						<button type="button" class="btn btn-primary" data-id=${v.id} ${disabledButton}>${v.started ? "Resgatar" : "Iniciar"}</button>
					</td>
				</tr>
			`);
		});

		$(document).on("click", ".btn.btn-primary", function() {
			let id = $(this).data("id")
			post(item.data[id - 1].started ? "redeemMission" : "initMission", {
				id: String(id),
			})
		})
	
	} else if (item.hide) {
		$("body").css("display", "none");

	}
});

document.onkeyup = function(data){
	if (data.key == "Escape") {
		if ($("body").is(":visible")){
			post("close","")
		}
	}
};

function post(name, data) {
	$.post("https://" + GetParentResourceName() + "/"+name, JSON.stringify(data), function(datab) {
		if (datab != "ok") console.log("WARN:"+datab);
	});
}